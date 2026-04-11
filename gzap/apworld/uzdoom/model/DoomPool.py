"""
Logic for selecting items/locations to randomize based on the player options.

The basic idea here is:
- create a bucket for each category in included_item_categories
- for each location, place it in the first matching bucket
- for each bucket, randomly choose (bucket size * inclusion ratio) locations
    - add these to the location pool
- for each location in the location pool, add its item to the item pool, if any
    - alternately, fix the item in place (vanilla positioning) or move it to
      the starting inventory
- add "loose items" to the item pool
- apply pool limits
- move items from the pool to the starting inventory
"""
import os

from collections import Counter
from math import ceil
from random import shuffle
from typing import List,Dict

class DoomPool:
    """
    A container for the locations and items to be added to the rando pool.

    You get one of these by asking a DoomWad to pick locations for randomization.
    Internally, it consists of a list of selected locations, a map of item names
    to item counts, and a bunch of utility functions for accessing different
    parts of this data.

    The main rando logic should never access the WAD's internal location/item
    data directly; instead it should get one of these and query it.
    """
    # All locations selected for randomization, based on their categories and
    # the settings in the yaml. These are the locations that will go in the AP
    # location pool, and the AP item pool will be based on (but not necessarily
    # identical to) the items from these locations.
    locations: List["DoomLocation"] = None
    # Locations that should be kept local-only and not reported to the apworld.
    local_locations: List["DoomLocation"] = None
    # All items in the pool, indexed by name.
    item_counts: Counter[str] = None
    # All starting inventory items, indexed by name.
    starting_item_counts: Counter[str] = None
    # Items forced to vanilla locations that should be removed from the pool.
    vanilla_item_counts: Counter[str]
    wad = None

    def __init__(self, wad, locations, world):
        self.wad = wad
        self.locations = []
        self.local_locations = []
        self.item_counts = Counter()
        self.starting_item_counts = Counter()
        self.vanilla_item_counts = Counter()
        self.select_locations(locations, world)
        self.remap_items(world)
        self.finalize_item_counts(world)

    def add_items_to_pool(self, counter, locations):
        for loc in (loc for loc in locations if loc.orig_item):
            # We do this because some items may have been remapped at the wad
            # level, e.g. "YellowKey (E1M1)" remapped to "YellowKey (E1)".
            # Doing so doesn't replace the original item in the individual
            # location, so we look it up int the wad and then use that.
            item = self.wad.items_by_name[loc.orig_item.name()]
            # if item is not loc.orig_item:
            #     print(f'Remap while filling pool: {loc.orig_item} -> {item}')
            counter[loc.orig_item.name()] += 1

    def _skip_in_pretuning(self, world, loc):
        return (
            world.options.pretuning_mode
            and loc.is_tuned()
            and 'GZAP_INCREMENTAL_PRETUNING' in os.environ
            and 'ap_flag' not in loc.categories
        )

    def select_locations(self, all_locations, world):
        '''
        Given all the locations in the wad, choose which locations will actually
        be randomized based on yaml settings. Locations are sorted into normal
        and forced-vanilla locations. Items are added to the item pool and,
        optionally, to the starting inventory pool.
        '''
        if world is None:
            self.locations = [loc for loc in all_locations if not loc.unreachable]
            self.add_items_to_pool(self.item_counts, self.locations)
            return

        buckets = {}
        for loc in all_locations:
            # Unreachable locations should be completely dropped from the
            # location set, as otherwise in a WAD with a large number of
            # unreachables it affects hint cost calculation badly.
            # TODO: once we implement tuning-only checks not visible to AP, we
            # should make unreachables a type of tuning-only check.
            if self._skip_in_pretuning(world, loc) or loc.unreachable:
                continue
            bucket = world.options.included_item_categories.bucket_for_location(loc)
            buckets.setdefault(bucket, []).append(loc)

        for bucket,locs in buckets.items():
            ratio = world.options.included_item_categories.ratio_for_bucket(bucket)
            # print(f'Considering bucket {bucket} with {len(locs)} locations and configured ratio {ratio}')

            if ratio == 0:
                # print('Skipping bucket', bucket)
                continue

            if ratio == 'vanilla':
                # Locations forced to hold their vanilla items. We add these
                # to a separate pool so the item/location placement code in
                # the UZDoomWorld knows what to do with them later.
                # print(f'Bucket {bucket} has vanilla items forced.')
                for loc in locs:
                    if loc.orig_item:
                        loc.item = loc.orig_item
                        self.vanilla_item_counts[loc.item.name()] += 1
                    elif world.options.pretuning_mode and not loc.item:
                        loc.item = self.wad.placeholder_item()
                self.locations.extend(locs)
                continue

            if ratio == 'shuffle':
                # Like vanilla, but we randomly match locations with items rather
                # than matching each location to its original item.
                for loc in locs:
                    assert loc.orig_item, f'shuffle is not allowed on empty locations: {loc.name()}'
                    assert not loc.has_category('ap_progression'), f'shuffle is not allowed on progression items: {loc.name()}'
                items = [loc.orig_item for loc in locs]
                shuffle(items)
                for loc in locs:
                    loc.item = items.pop()
                    self.vanilla_item_counts[loc.item.name()] += 1
                self.local_locations.extend(locs)
                continue

            if ratio == 'start':
                # Locations that should have their items moved to the player's
                # starting inventory (and the locations themselves acting as
                # normal checks). We record these in the starting item pool *but
                # also* record the items and locations in the main pool; we do
                # it this way so that pool limits get applied properly.
                # print(f'Adding bucket {bucket} to starting inventory.')
                # TODO: this doesn't work for items that weren't visible to the
                # logic file, so you can't use this to grant the player starting
                # items that the scanner doesn't know about, even if they can
                # be `summoned.
                self.add_items_to_pool(self.starting_item_counts, locs)
                ratio = 1.0

            if hasattr(world.multiworld, "generation_is_fake"):
                # Universal Tracker support. If UT is generating, include all
                # locations that could potentially be in the pool, whether they
                # were or not.
                ratio = 1.0

            # Select a random subset of the locations in this bucket, put the
            # locations themselves in the location pool and the items contained
            # there in the item pool.
            selected_locs = world.random.sample(locs, ceil(len(locs)*ratio))
            # print(f'Selecting {len(selected_locs)} from {bucket} with ratio {ratio}')
            self.locations.extend(selected_locs)
            self.add_items_to_pool(self.item_counts, selected_locs)

    def remap_items(self, world):
        '''
        This runs just before finalize_item_counts and is used to replace items
        that should inform the final contents of the pool but not actually be
        included in it, such as replacing actual weapons with weapon capability
        grants.
        '''
        new_items = Counter()
        for name,count in self.item_counts.items():
            item = self.wad.item(name)
            if item.has_category('weapon'):
                self.item_counts[name] -= count
                if not world.options.per_map_weapons:
                    # print('remap:', name, self.wad.weapon_capability(item.typename))
                    new_items[self.wad.weapon_capability(item.typename)] = count
                else:
                    for map in world.maps:
                        # print('remap:', name, self.wad.weapon_capability(item.typename, map.map))
                        new_items[self.wad.weapon_capability(item.typename, map.map)] = count

        self.item_counts += new_items

    def finalize_item_counts(self, world):
        '''
        This runs after all location-sourced items are added to the pool. Here
        is where we add "loose" items that don't come from locations (like
        access and victory flags), apply item limits, and remove starting items.
        '''
        # Not generating anything, so we skip anything that depends on settings.
        if world is None:
            return

        # Add all non-location-based items to the pool based on which maps were
        # selected.
        for map in world.maps:
            for item,count in map.loose_items.items():
                ratio = world.options.included_item_categories.ratio_for_item(self.wad.item(item))
                self.item_counts[item] += count
                # print(f'Adding {count} copies of {item} from {map.map}')
                # We don't really respect ratios here except for starting-inventory,
                # because these loose items are load bearing for the randomizer
                # and have no vanilla location, so they cannot be excluded or
                # vanilla-placed.
                if ratio == 'start':
                    self.starting_item_counts[item] += count
                elif ratio != 1.0:
                    raise RuntimeError(f'AP-generated item {item} from {map.map} has invalid included_item_categories setting of "{ratio}"')

        # Apply item lower/upper bounds.
        # Items set to 'vanilla' or 'shuffle' skip this.
        for name in self.item_counts.keys():
            if name in self.vanilla_item_counts:
                continue
            item = self.wad.item(name)
            (lower,upper) = item.pool_limits(world)
            # print(f'Adjust count for {item.name()} from {self.item_counts[item.name()]} to ({lower},{upper})')
            self.item_counts[item.name()] = max(lower, min(self.item_counts[item.name()], upper))

        # Withdraw starting inventory from the pool only after limits are applied.
        for item,count in self.starting_item_counts.items():
            if count <= self.item_counts[item]:
                self.item_counts[item] -= count
            else:
                self.starting_item_counts[item] = self.item_counts[item]
                self.item_counts[item] = 0

    def adjust_item(self, item, count):
        self.item_counts[item] = self.item_counts.get(item, 0) + count

    def locations_in_map(self, map):
        return [
            loc for loc in self.locations
            if loc.pos.map == map
        ]

    def all_pool_items(self):
        return [
            self.wad.item(name)
            for name in sorted(
            { name for name in self.item_counts.keys() } | { name for name in self.vanilla_item_counts.keys() })]

    def progression_items(self):
        return Counter({
            name: count
            for name,count in self.item_counts.items()
            if self.wad.item(name).is_progression()
        })

    def useful_items(self):
        return Counter({
            name: count
            for name,count in self.item_counts.items()
            if self.wad.item(name).is_useful()
        })

    def filler_items(self):
        return Counter({
            name: count
            for name,count in self.item_counts.items()
            if self.wad.item(name).is_filler()
            and count > 0
        })

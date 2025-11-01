"""
Logic for selecting items/locations to randomize based on the player options.

The basic idea here is:
- create a bucket for each category in included_item_categories
- for each location, place it in the first matching bucket
- for each bucket, randomly choose (bucket size * inclusion ratio) locations
    - add these to the location pool
- for each location in the location pool, add its item to the item pool, if any
- add "loose items" to the item pool
- apply pool limits
- TODO: optionally move items from the pool to the starting inventory or their
        default locations, if configured
"""
from collections import Counter
from math import ceil
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
    # Locations with vanilla placement forced will have their .item field set
    # accordingly.
    locations: List["DoomLocation"] = None
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
        self.vanilla_locations = []
        self.item_counts = Counter()
        self.starting_item_counts = Counter()
        self.vanilla_item_counts = Counter()
        self.select_locations(locations, world)
        self.finalize_item_counts(world)

    def add_items_to_pool(self, counter, locations):
        for loc in (loc for loc in locations if loc.orig_item):
            counter[loc.orig_item.name()] += 1

    def select_locations(self, all_locations, world):
        '''
        Given all the locations in the wad, choose which locations will actually
        be randomized based on yaml settings. Locations are sorted into normal
        and forced-vanilla locations. Items are added to the item pool and,
        optionally, to the starting inventory pool.
        '''
        if world is None:
            self.locations = [loc for loc in all_locations if loc.is_default_enabled()]
            self.add_items_to_pool(self.item_counts, self.locations)
            return

        buckets = {}
        for loc in all_locations:
            bucket = world.options.included_item_categories.find_bucket(loc)
            buckets.setdefault(bucket, []).append(loc)

        for bucket,locs in buckets.items():
            ratio = world.options.included_item_categories.ratio_for_bucket(bucket)
            # print(f'Considering bucket {bucket} with {len(locs)} locations and configured ratio {ratio}')
            if world.options.pretuning_mode:
                ratio = 'vanilla'

            if ratio == 0:
                # print('Skipping bucket', bucket)
                continue

            if ratio == 'vanilla':
                # Locations forced to hold their vanilla items. We add these
                # to a separate pool so the item/location placement code in
                # the GZDoomWorld knows what to do with them later.
                # print(f'Bucket {bucket} has vanilla items forced.')
                for loc in locs:
                    if loc.orig_item:
                        loc.item = loc.orig_item
                        self.vanilla_item_counts[loc.item.name()] += 1
                    elif world.options.pretuning_mode and not loc.item:
                        loc.item = self.wad.placeholder_item()
                self.locations.extend(locs)
                continue

            if ratio == 'start':
                # Locations that should have their items moved to the player's
                # starting inventory (and the locations themselves acting as
                # normal checks). We record these in the starting item pool *but
                # also* record the items and locations in the main pool; we do
                # it this way so that pool limits get applied properly.
                # print(f'Adding bucket {bucket} to starting inventory.')
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

    def finalize_item_counts(self, world):
        '''
        Do final tidying of the item pool. This means adding items to it that
        don't come from locations (like access and victory tokens), applying
        pool limits, and then removing starting items from the pool so that they
        exist only in the starting-item pool.
        '''
        # Not generating anything, so we skip anything that depends on settings.
        if world is None:
            return

        # Add all non-location-based items to the pool based on which maps were
        # selected.
        for map in world.maps:
            for item,count in map.loose_items.items():
                ratio = world.options.included_item_categories.find_ratio(self.wad.item(item))
                self.item_counts[item] += count
                if ratio == 'start':
                    self.starting_item_counts[item] += count

        # Apply item lower/upper bounds.
        # Items set to 'vanilla' skip this.
        for item in self.wad.items():
            if item.name() in self.vanilla_item_counts:
                continue
            (lower,upper) = item.pool_limits(world)
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

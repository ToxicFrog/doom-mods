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
    locations: List["DoomLocation"] = None
    # All items in the pool, indexed by name.
    item_counts: Counter[str] = None
    wad = None

    def __init__(self, wad, locations, world):
        self.wad = wad
        self.locations = self.select_locations(locations, world)
        self.item_counts = self.prepare_item_counts(world)

    def select_locations(self, all_locations, world):
        '''
        Given a set of locations covering the entire wad, choose a subset of those
        locations based on the yaml settings.
        '''
        buckets = {}
        for loc in all_locations:
            bucket = world.options.included_item_categories.find_bucket(loc)
            buckets.setdefault(bucket, []).append(loc)

        selected_locations = []
        ratios = world.options.included_item_categories.all_ratios()
        for bucket,locs in buckets.items():
            ratio = ratios[bucket]
            if ratio == 0:
                continue

            if hasattr(world.multiworld, "generation_is_fake"):
                # Universal Tracker support. If UT is generating, include all
                # locations that could potentially be in the pool, whether they
                # were or not.
                ratio = 1.0

            selected_locations.extend(world.random.sample(locs, ceil(len(locs)*ratio)))
        return selected_locations

    def prepare_item_counts(self, world):
        '''
        Fill the item pool. This is initially based on the contents of the
        location pool, but it can also have "loose" items not sourced from any
        location (like level access tokens) added to it, and individual item
        definitions can also set lower and upper bounds on how many of that item
        can be in the pool.
        '''
        counts = Counter()
        for loc in self.locations:
            item = loc.orig_item
            if item is None:
                continue
            counts[item.name()] += 1

        # Not generating anything, so we skip anything that depends on settings.
        if world is None:
            return counts

        # Get the 'loose items', like access tokens, from each map, and insert
        # them into the pool.
        for map in world.maps:
            for item,count in map.loose_items.items():
                counts[item] += count

        # Apply item lower/upper bounds.
        for item in self.wad.items():
            (lower,upper) = item.pool_limits(world)
            counts[item.name()] = max(lower, min(counts[item.name()], upper))
            # if counts[item.name()] != count:
            #     print(f"Updating count of {item.name()} from {count} to {counts[item.name()]}")

        return counts

    def adjust_item(self, item, count):
        self.item_counts[item] = self.item_counts.get(item, 0) + count

    def locations_in_map(self, map):
        return [
            loc for loc in self.locations
            if loc.pos.map == map
        ]

    def all_pool_items(self):
        return [self.wad.item(name) for name in self.item_counts.keys()]

    def progression_items(self):
        return {
            name: count
            for name,count in self.item_counts.items()
            if self.wad.item(name).is_progression()
        }

    def useful_items(self):
        return {
            name: count
            for name,count in self.item_counts.items()
            if self.wad.item(name).is_useful()
        }

    def filler_items(self):
        return {
            name: count
            for name,count in self.item_counts.items()
            if self.wad.item(name).is_filler()
        }

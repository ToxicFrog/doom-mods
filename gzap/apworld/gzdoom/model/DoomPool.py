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
    locations: List["DoomLocation"] = None
    item_counts: Dict[str,int] = None
    wad = None

    def __init__(self, wad, locations, world):
        self.wad = wad
        self.locations = locations
        self.item_counts = self.prepare_item_counts(world)

    def prepare_item_counts(self, world):
        counts = {}
        for loc in self.locations:
            item = loc.orig_item
            if item is None:
                continue
            counts[item.name()] = counts.get(item.name(), 0) + 1

        if world is None:
            return counts

        for map in world.maps:
            for item,count in map.loose_items.items():
                counts[item] = counts.get(item, 0) + count

        for item in self.wad.items():
            (lower,upper) = item.pool_limits(world)
            count = counts.get(item.name(), 0)
            counts[item.name()] = max(lower, min(count, upper))
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

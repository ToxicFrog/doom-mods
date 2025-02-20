"""
Data model for a (mega)WAD.

At generation time, generation operates on a single wad. So the wad model needs
to keep track of:
- what levels are in the wad
- what locations are in those levels (and must thus be added to the pool)
- what items were originally in those locations (likewise)
- what difficulty level to play on
- what map to start on

"""

from dataclasses import dataclass, field, InitVar
from typing import Any, Dict, List

from . import DoomItem, DoomLocation, DoomMap, DoomPosition


class DuplicateMapError(RuntimeError):
    """
    Someday we'll want to support multiple copies of the same map at different
    difficulty settings. Today is not that day.
    """
    pass


@dataclass
class DoomWad:
    name: str
    logic: Any  # actually DoomLogic, but no circular dependencies please
    skill: int = 3  # 1-indexed like the command line, so 3 == HMP.
    maps: Dict[str,DoomMap] = field(default_factory=dict)
    items_by_name: Dict[str,DoomItem] = field(default_factory=dict)
    locations_by_name: Dict[str,DoomLocation] = field(default_factory=dict)
    locations_by_pos: Dict[DoomPosition,DoomLocation] = field(default_factory=dict)
    first_map: DoomMap | None = None

    def locations(self) -> List[DoomLocation]:
        return [loc for loc in self.locations_by_name.values() if loc]

    def items(self) -> List[DoomItem]:
        return [item for item in self.items_by_name.values() if item]

    def item(self, name: str) -> DoomItem:
        return self.items_by_name[name]

    def progression_items(self) -> List[DoomItem]:
        return [item for item in self.items() if item.is_progression()]

    def useful_items(self) -> List[DoomItem]:
        return [item for item in self.items() if item.is_useful()]

    def filler_items(self) -> List[DoomItem]:
        return [item for item in self.items() if item.is_filler()]

    def all_maps(self) -> List[DoomMap]:
        return self.maps.values()


    def new_map(self, json: Dict[str,str]) -> None:
        map = json["map"]
        if map in self.maps:
            # TODO: support multiple copies of the same map as long as they
            # have different difficulty levels, so we can have a single logic
            # file for all difficulties of a given wad.
            raise DuplicateMapError(map)

        prior_clears = set([map.clear_token_name() for map in self.maps.values()])
        self.maps[map] = DoomMap(prior_clears=prior_clears, **json)
        self.register_map_tokens(self.maps[map])

        if self.first_map is None:
            self.first_map = self.maps[map]

    def register_map_tokens(self, map: DoomMap):
        self.register_item(None,
            DoomItem(map=map.map, category="token", typename="", tag="Level Access"))
        self.register_item(None,
            DoomItem(map=map.map, category="map", typename="", tag="Automap"))
        clear_token = self.register_item(None,
            DoomItem(map=map.map, category="token", typename="", tag="Level Clear"))
        map_exit = DoomLocation(self, map.map, clear_token, None)
        # TODO: there should be a better way of overriding location names
        map_exit.item_name = "Exit"
        map_exit.item = clear_token
        self.register_location(map_exit)


    def new_item(self, json: Dict[str,str]) -> None:
        """
        Add a new item to the item pool, and its position to the location pool.

        If it's a new kind of item, we allocate an ID for it and create an entry in the item table. Otherwise
        we just increment the count on the existing entry. The item's location is added to the location pool
        using the item's name as a disambiguator.

        This is also where the keyset for the enclosing map gets updated.
        """
        # Extract the position information for addition to the location table.
        map = json["map"]
        position = json.pop("position")
        secret = json.pop("secret", False)

        # Provisionally create a DoomItem.
        item = DoomItem(**json)

        # Do we actually care about these? If not, don't generate an ID for this item or add it to the pool,
        # and don't consider its location as a valid randomization destination.
        if not item.can_replace():
            return

        # We know we care about the location, so register it.
        self.new_location(map, item, position)

        # Register the item as well, if it's eligible to be included in the item pool.
        if item.should_include():
            self.register_item(map, item, secret)

    def register_item(self, map: str, item: DoomItem, secret: bool = False) -> DoomItem:
        if item.name() in self.items_by_name:
            return self.register_duplicate_item(map, item, secret)

        if map is not None:
            self.maps[map].update_access_tracking(item)

        self.logic.register_item(item)
        self.items_by_name[item.name()] = item
        return item

    def register_duplicate_item(self, map: str, item: DoomItem, secret: bool = False) -> DoomItem:
        other: DoomItem = self.items_by_name[item.name()]
        if other == item:
            if map is not None:
                self.maps[map].update_access_tracking(item)
            other.count += 1
            return other

        if other is False:
            # Known to require disambiguation. Set the disambiguation bit
            # and retry.
            assert not item.disambiguate
            item.disambiguate = True
            return self.register_item(map, item, secret)

        # Name collision with existing, different item. We need to rename
        # them both.
        assert not (item.disambiguate or other.disambiguate)
        # Leave behind False as a sentinel value so future duplicates
        # get disambiguated properly.
        self.items_by_name[other.name()] = False
        # We don't need to specify the map here because the map was already
        # updated with this item, if necessary, the first time we saw it, and
        # changing its canonical name doesn't affect that.
        other.disambiguate = True
        item.disambiguate = True
        self.register_item(None, other)
        return self.register_item(map, item, secret)


    def new_location(self, map: str, item: DoomItem, json: Dict[str, str]) -> None:
        """
        Add a new location to the location pool.

        If it is identical (same position) as an existing location, it is silently dropped. This is,
        fortunately, rare. If multiple locations share the same position but have different items,
        all of their items are added to the pool but it's undefined which one the location is named
        after and inherits the item category from.
        """
        location = DoomLocation(self, map, item, json)
        self.register_location(location)

    def register_location(self, location: DoomLocation, force: bool = False) -> DoomLocation:
        if not force and location.pos in self.locations_by_pos:
            # Duplicate location; ignore it
            return self.locations_by_pos[location.pos]

        if not force and location.name() in self.locations_by_name:
            # No chance that these are two references to "the same" location,
            # since location sameness is based on position and we just checked that.
            return self.register_duplicate_location(location)

        self.logic.register_location(location)
        self.locations_by_name[location.name()] = location
        self.maps[location.pos.map].register_location(location)
        if not location.pos.virtual:
            self.locations_by_pos[location.pos] = location
        return location

    def register_duplicate_location(self, location: DoomLocation) -> DoomLocation:
        other: DoomLocation = self.locations_by_name[location.name()]
        # print("Name collision between locations:")
        # print("old:", other)
        # print("new:", location)

        if other is False:
            # Known to require disambiguation. Set the disambiguation bit
            # and retry.
            assert not location.disambiguate
            location.disambiguate = True
            return self.register_location(location)

        assert not (location.disambiguate or other.disambiguate)
        # Leave behind False as a sentinel value so future duplicates
        # get disambiguated properly.
        self.locations_by_name[other.name()] = False
        other.disambiguate = True
        location.disambiguate = True
        self.register_location(other, force=True)
        return self.register_location(location)

    def tune_location(self, id, name, keys) -> None:
        """
        Adjust the reachability rules for a location.

        This is emitted by the game when the player checks a location, and records
        what keys they had when this happened. This can be used to minimize the keyset
        for a given location.

        This needs to run after AP-SCAN-DONE so that the keysets are initialized,
        which shouldn't be a problem in practice unless people are assembling play
        logs out of order.
        """
        self.locations_by_name[name].tune_keys(set(keys))


    def finalize_scan(self, json) -> None:
        """
        Do postprocessing after the initial scan is completed but before play-guided refinement, if any.

        At the moment this means creating the synthetic level-exit and level-cleared locations and items,
        then pessimistically initializing the keyset for each location to match the keys of the enclosing map.
        """
        self.skill = json["skill"]

        for loc in self.locations():
            loc.keyset = self.maps[loc.pos.map].keyset.copy()


    def finalize_all(self) -> None:
        """
        Do postprocessing after all events have been ingested.

        Caps guns at 1 per gun per episode (ish), and keys at 1 per type per map.
        """
        max_guns = len(self.maps)//8
        for item in self.items():
            if item.category == "weapon":
                item.count = min(item.count, max_guns)
            elif item.category == "key":
                item.count = 1

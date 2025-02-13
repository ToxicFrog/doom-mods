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
from typing import Dict, List

from . import DoomItem, DoomLocation, DoomMap, DoomPosition


class DuplicateMapError(RuntimeError):
    """
    Someday we'll want to support multiple copies of the same map at different
    difficulty settings. Today is not that day.
    """
    pass


@dataclass
class DoomWad:
    last_id: int = 0
    skill: int = 3  # 1-indexed like the command line, so 3 == HMP.
    maps: Dict[str,DoomMap] = field(default_factory=dict)
    items_by_name: Dict[str,DoomItem] = field(default_factory=dict)
    locations_by_name: Dict[str,DoomLocation] = field(default_factory=dict)
    locations_by_pos: Dict[DoomPosition,DoomLocation] = field(default_factory=dict)
    first_map: DoomMap | None = None

    def get_id(self) -> int:
        self.last_id += 1
        return self.last_id

    def all_maps(self) -> List[DoomMap]:
        return self.maps.values()

    def all_locations(self) -> List[DoomLocation]:
        return self.locations_by_name.values()

    def all_items(self) -> List[DoomItem]:
        return self.items_by_name.values()

    def starting_items(self) -> List[DoomItem]:
        return [
            self.items_by_name[self.first_map.access_token_name()]
        ] + list(self.first_map.keyset)

    def new_map(self, json: Dict[str,str]) -> None:
        map = json["map"]
        if map not in self.maps:
            self.maps[map] = DoomMap(
                access_id=self.get_id(), automap_id=self.get_id(),
                clear_id=self.get_id(), exit_id=self.get_id(),
                **json)
        else:
            # TODO: support multiple copies of the same map as long as they
            # have different difficulty levels, so we can have a single logic
            # file for all difficulties of a given wad.
            raise DuplicateMapError(map)

        if self.first_map is None:
            self.first_map = self.maps[map]

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
        position = json["position"]
        del json["position"]

        # Provisionally create a DoomItem.
        item = DoomItem(**json)
        # Do we actually care about these? If not, don't generate an ID for this item or add it to the pool,
        # and don't consider its location as a valid randomization destination.
        if not item.can_replace():
            return

        if item.should_include():
            self.add_item(map, item, position["secret"])
        self.new_location(map, item, position)

    def add_item(self, map: str, item: DoomItem, secret: bool) -> None:
        # If we haven't seen this kind of item before, give it an ID and put
        # it in the lookup table, otherwise update the count for the existing
        # DoomItem.
        if item.name not in self.items_by_name:
            item.id = item.id or self.get_id()
            self.items_by_name[item.name] = item
        else:
            item = self.items_by_name[item.name]
            item.count += 1

        if item.category == "key":
            self.maps[map].keyset.add(item)
        if item.category == "weapon" and not secret:
            self.maps[map].gunset.add(item)

    def new_location(self, map: str, item: DoomItem, json: Dict[str, str]) -> None:
        """
        Add a new location to the location pool.

        If it is identical (same position) as an existing location, it is silently dropped. This is,
        fortunately, rare. If multiple locations share the same position but have different items,
        all of their items are added to the pool but it's undefined which one the location is named
        after and inherits the item category from.
        """
        location = DoomLocation(self, map, item, json)

        # FIXME: this isn't parameterized by map, so if we have a check at the same coordinates
        # in two maps, they'll get deduplicated. Things will still work but the name will be
        # wrong in one of them.
        if location.pos in self.locations_by_pos:
            # Duplicate location; ignore it
            return

        self.add_location(location)

    def add_location(self, location: DoomLocation) -> None:
        # Caller has already done position duplicate checking
        location.id = location.id or self.get_id()
        if location.name in self.locations_by_name:
            location.name = f"{location.name} <{location.id}>"

        self.maps[location.map].locations.append(location)
        self.locations_by_name[location.name] = location
        if location.pos:
            self.locations_by_pos[location.pos] = location

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
        loc = self.locations_by_name[name]
        keys = { self.items_by_name[f"{key} ({loc.map})"] for key in keys }
        self.locations_by_name[name].tune_keys(keys)

    def finalize_scan(self, json) -> None:
        """
        Do postprocessing after the initial scan is completed but before play-guided refinement, if any.

        At the moment this means creating the synthetic level-exit and level-cleared locations and items,
        then pessimistically initializing the keyset for each location to match the keys of the enclosing map.
        """
        self.skill = json["skill"]

        for map in self.all_maps():
            access_token = DoomItem(map=map.map, category="token", typename="", tag="Level Access")
            access_token.id = map.access_id
            self.add_item(map.map, access_token, False)

            map_token = DoomItem(map=map.map, category="map", typename="", tag="Automap")
            map_token.id = map.automap_id
            self.add_item(map.map, map_token, False)

            clear_token = DoomItem(map=map.map, category="token", typename="", tag="Level Clear")
            clear_token.id = map.clear_id
            self.add_item(map.map, clear_token, False)

            map_exit = DoomLocation(self, map.map, clear_token, None)
            map_exit.id = map.exit_id
            map_exit.item = clear_token
            map_exit.name = f"{map.map} - Exit"
            self.add_location(map_exit)

        for loc in self.all_locations():
            loc.keyset = self.maps[loc.map].keyset.copy()


    def finalize_all(self) -> None:
        """
        Do postprocessing after all events have been ingested.

        Caps guns at 1 per gun per episode (ish), and keys at 1 per type per map.
        """
        max_guns = len(self.maps)//8
        for item in self.all_items():
            if item.category == "weapon":
                item.count = min(item.count, max_guns)
            elif item.category == "key":
                item.count = 1

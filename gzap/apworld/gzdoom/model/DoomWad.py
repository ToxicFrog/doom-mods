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
from typing import Any, Dict, List, Set

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
    maps: Dict[str,DoomMap] = field(default_factory=dict)
    items_by_name: Dict[str,DoomItem] = field(default_factory=dict)
    # Map of skill -> position -> location used while importing locations.
    locations_by_pos: Dict[int,Dict[DoomPosition,DoomLocation]] = field(default_factory=dict)
    locations_by_name: Dict[str,DoomLocation] = field(default_factory=dict)
    first_map: DoomMap | None = None

    def __post_init__(self):
        self.locations_by_pos = {
            1: {},
            2: {},
            3: {},
        }

    def locations(self, skill: int) -> List[DoomLocation]:
        skill = min(3, max(1, skill)) # clamp ITYTD->HNTR and N!->UV
        return [loc for loc in self.locations_by_name.values() if skill in loc.skill]

    def items(self, skill: int) -> List[DoomItem]:
        skill = min(3, max(1, skill)) # clamp ITYTD->HNTR and N!->UV
        return [
            item for item in self.items_by_name.values()
            if item and item.count.get(skill, 0) > 0
        ]

    def item(self, name: str) -> DoomItem:
        return self.items_by_name[name]

    def progression_items(self, skill: int) -> List[DoomItem]:
        return [item for item in self.items(skill) if item.is_progression()]

    def useful_items(self, skill: int) -> List[DoomItem]:
        return [item for item in self.items(skill) if item.is_useful()]

    def filler_items(self, skill: int) -> List[DoomItem]:
        return [item for item in self.items(skill) if item.is_filler()]

    def all_maps(self) -> List[DoomMap]:
        return self.maps.values()


    def new_map(self, json: Dict[str,str]) -> None:
        map = json["map"]
        if map in self.maps:
            raise DuplicateMapError(map)

        self.maps[map] = DoomMap(**json)
        self.register_map_tokens(self.maps[map])

        if self.first_map is None:
            self.first_map = self.maps[map]

    def register_map_tokens(self, map: DoomMap):
        self.register_item(None,
            DoomItem(map=map.map, category="token", typename="", tag="Level Access", skill=set([1,2,3])))
        self.register_item(None,
            DoomItem(map=map.map, category="map", typename="", tag="Automap", skill=set([1,2,3])))
        clear_token = self.register_item(None,
            DoomItem(map=map.map, category="token", typename="", tag="Level Clear", skill=set([1,2,3])))
        map_exit = DoomLocation(self, map.map, clear_token, None)
        # TODO: there should be a better way of overriding location names
        map_exit.item_name = "Exit"
        map_exit.item = clear_token
        self.register_location(map_exit, set([1, 2, 3]))


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
        skill = set(json.pop("skill", [1,2,3]))
        # TODO: secret is not actually used for anything right now. We should
        # annotate the location with it, not the item, and we should have an option
        # to avoid placing progression items in secret locations.
        secret = json.pop("secret", False)

        # Provisionally create a DoomItem.
        item = DoomItem(skill=skill, **json)

        # Do we actually care about these? If not, don't generate an ID for this item or add it to the pool,
        # and don't consider its location as a valid randomization destination.
        if not item.can_replace():
            return

        # We know we care about the location, so register it.
        self.new_location(map, item, position, skill)

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
                # Record this key/gun as something the player should have before
                # this level is in logic.
                # TODO: we may need to maintain different keysets/gunsets for
                # different skills (but hopefully not).
                self.maps[map].update_access_tracking(item)
            other.update_skill_from(item)
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


    def new_location(self, map: str, item: DoomItem, json: Dict[str, str], skill: Set[int]) -> None:
        """
        Add a new location to the location pool.

        If it is identical (same position) as an existing location, it is silently dropped. This is,
        fortunately, rare. If multiple locations share the same position but have different items,
        all of their items are added to the pool but it's undefined which one the location is named
        after and inherits the item category from.
        """
        location = DoomLocation(self, map, item, json)
        self.register_location(location, skill)

    def register_location(self, location: DoomLocation, skill: Set[int]) -> None:
        if location.pos.virtual:
            # Virtual location, is not part of the deduplication table.
            location.skill = skill.copy()
            self.maps[location.pos.map].register_location(location)
            return

        for sk in skill:
            locs_by_pos = self.locations_by_pos[sk]
            if location.pos in locs_by_pos:
                # We already have a location registered at these coordinates for
                # this skill.
                continue

            # Don't do name disambiguation or register it with the top-level
            # logic yet -- we'll do both of those things after we've ingested
            # the entire wad and can scan the whole thing for name collisions.
            location.skill.add(sk)
            locs_by_pos[location.pos] = location
            self.maps[location.pos.map].register_location(location)
            # self.logic.register_location(location)
            # self.locations_by_name[location.name()] = location


    def tune_location(self, id, name, keys, unreachable = False) -> None:
        """
        Adjust the reachability rules for a location.

        This is emitted by the game when the player checks a location, and records
        what keys they had when this happened. This can be used to minimize the keyset
        for a given location.

        This needs to run after AP-SCAN-DONE so that the keysets are initialized,
        which shouldn't be a problem in practice unless people are assembling play
        logs out of order.
        """
        # Index by name rather than ID because the ID may change as more WADs
        # are added, but the name should not.
        loc = self.locations_by_name.get(name, None)
        if loc is None:
            return
        if unreachable:
            loc.unreachable = True
        else:
          loc.tune_keys(set(keys))


    def finalize_scan(self, json) -> None:
        """
        Do postprocessing after the initial scan is completed but before tuning.
        """
        # Resolve name collisions among locations and register them with the logic.
        # We iterate the maps here, rather than locations_by_pos, because virtual
        # locations like exits don't appear in the position table but do appear
        # in their corresponding maps.
        name_to_loc = {}
        for map in self.maps.values():
            for location in map.locations:
                name_to_loc.setdefault(location.name(), []).append(location)

        for locs in name_to_loc.values():
            if len(locs) > 1:
                for loc in locs:
                    loc.disambiguate = True
            for loc in locs:
              self.logic.register_location(loc)
              self.locations_by_name[loc.name()] = loc
              # While we're here, initialize all location keysets based on the keyset
              # of their containing map. Tuning may adjust these later.
              loc.keyset = self.maps[loc.pos.map].keyset.copy()


    def finalize_all(self) -> None:
        """
        Do postprocessing after all events have been ingested.

        Caps keys at 1 of each colour per map.
        """
        for item in self.items_by_name.values():
            if item.category == "key":
                item.set_max_count(1)

        for map in self.all_maps():
            map.prior_clears = set([
                prior_map.clear_token_name()
                for prior_map in self.all_maps()
                if prior_map.rank < map.rank
            ])

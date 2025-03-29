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
from typing import Any, Dict, List, Set, FrozenSet

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

    def get_map(self, name: str) -> DoomMap:
        return self.maps[name]

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
        map_exit = DoomLocation(self, map=map.map, item=clear_token, secret=False, json=None)
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
        secret = json.pop("secret", False)

        # We add everything in the logic file to the pool. Not everything will
        # necessarily be used in randomization, but we need to do this at load
        # time, before we know what item categories the user has requested.
        item = DoomItem(skill=skill, **json)
        self.new_location(map, item, secret, skill, position)
        self.register_item(map, item)

    def register_item(self, map: str, item: DoomItem) -> DoomItem:
        if item.name() in self.items_by_name:
            return self.register_duplicate_item(map, item)

        if map is not None:
            self.maps[map].update_access_tracking(item)

        self.logic.register_item(item)
        self.items_by_name[item.name()] = item
        return item

    def register_duplicate_item(self, map: str, item: DoomItem) -> DoomItem:
        other: DoomItem = self.items_by_name[item.name()]
        if other is False:
            # Known to require disambiguation. Set the disambiguation bit
            # and retry.
            assert not item.disambiguate
            item.disambiguate = True
            return self.register_item(map, item)

        if other == item:
            if map is not None:
                # Record this key/gun as something the player should have before
                # this level is in logic.
                # TODO: we may need to maintain different keysets/gunsets for
                # different skills (but hopefully not).
                self.maps[map].update_access_tracking(item)
            other.update_skill_from(item)
            return other

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
        return self.register_item(map, item)


    def new_location(self, map: str, item: DoomItem, secret: bool, skill: Set[int], json: Dict[str, str]) -> None:
        """
        Add a new location to the location pool.

        If it is identical (same position) as an existing location, it is silently dropped. This is,
        fortunately, rare. If multiple locations share the same position but have different items,
        all of their items are added to the pool but it's undefined which one the location is named
        after and inherits the item category from.
        """
        location = DoomLocation(self, map, item, secret, json)
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
          # Before passing the keys to tune_keys, we need to annotate them with
          # the map name so that they match the names that Archipelago expects.
          # TODO: When we support keys with greater-than-one-map scope, this
          # gets more complicated. Probably we have some information supplied
          # earlier in the tuning file we use to do the conversion.
          loc.tune_keys(frozenset([loc.fqin(key) for key in keys]))


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
                    # TODO: handle the case where merely setting disambiguate
                    # is not enough because there are two checks with identical
                    # XY coordinates but different Z.
                    loc.disambiguate = True
            for loc in locs:
              self.logic.register_location(loc)
              self.locations_by_name[loc.name()] = loc
              # While we're here, initialize all location keysets based on the keyset
              # of their containing map. Tuning may adjust these later.
              loc.keys = frozenset([frozenset(self.maps[loc.pos.map].keyset.copy())])


    def finalize_all(self) -> None:
        """
        Do postprocessing after all events have been ingested.
        """
        # A key always has one copy in the item pool regardless of spawn filter.
        # TODO: this is a workaround for the fact that, if a key only exists on
        # some difficulties, the initial scan considers the level to never be
        # in logic on difficulties where it doesn't exist (because you can
        # never find all the keys). The real fix for this is to implement non-
        # randomized tuning and tune the affected level(s) first.
        self.items_by_name = {
            key: value
            for key,value in self.items_by_name.items()
            if value
        }
        for item in self.items_by_name.values():
            if item.category == "key":
                item.set_count(1)

        # Compute which maps precede which other maps, so that the map ordering
        # system can function.
        for map in self.all_maps():
            map.prior_clears = set([
                prior_map.clear_token_name()
                for prior_map in self.all_maps()
                if prior_map.rank < map.rank
            ])

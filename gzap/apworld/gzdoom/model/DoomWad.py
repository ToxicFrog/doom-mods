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

import sys

from dataclasses import dataclass, field, InitVar
from typing import Any, Dict, List, Set, FrozenSet, Tuple

from .BoundingBox import BoundingBox
from .DoomPool import DoomPool
from .DoomItem import DoomItem
from .DoomLocation import DoomLocation, DoomPosition
from .DoomMap import DoomMap
from .DoomKey import DoomKey


class DuplicateMapError(RuntimeError):
    """
    A logic file needs to contain one entry per map. Multiple difficulty levels
    are encoded into the individual locations.
    """
    pass


@dataclass
class DoomWad:
    name: str
    maps: Dict[str,DoomMap] = field(default_factory=dict)
    items_by_name: Dict[str,DoomItem] = field(default_factory=dict)
    # Map of skill -> position -> location used while importing locations.
    locations_by_pos: Dict[int,Dict[DoomPosition,DoomLocation]] = field(default_factory=dict)
    # Map of FQIN -> key record
    keys_by_name: Dict[str,DoomKey] = field(default_factory=dict)
    # Location lookup by legacy name, now used only for processing legacy tuning
    # files that don't include location coordinates + virtual locations that only
    # have a name, not a position.
    # Might contain multiple locations with the same name in rare cases where the
    # same position contains items with different underlying type but same display
    # name on different difficulties.
    locations_by_name: Dict[str,List[DoomLocation]] = field(default_factory=dict)
    first_map: DoomMap | None = None

    def __post_init__(self):
        self.locations_by_pos = {
            1: {},
            2: {},
            3: {},
        }

    def locations_for_stats(self, skill: int) -> List[DoomLocation]:
        skill = min(3, max(1, skill)) # clamp ITYTD->HNTR and N!->UV
        return [
            loc for map in self.maps.values() for loc in map.all_locations(skill, {})
            if loc.orig_item and loc.orig_item.is_default_enabled()
        ]

    def locations_at_position(self, pos: DoomPosition) -> List[DoomLocation]:
        """
        Returns all locations at the specified position. This is [] if there are
        no locations there; if there's a different item there on every difficulty,
        it could be as many as three different locations.
        """
        return [
            locs[pos]
            for locs in self.locations_by_pos.values()
            if pos in locs
        ]

    def stats_pool(self, skill):
        """Returns a DoomPool suitable for reporting stats about the wad."""
        return DoomPool(self, self.locations_for_stats(skill), None)

    def fill_pool(self, world):
        """
        Returns a DoomPool containing all of the locations and items to be used
        for randomization.

        The randomizer never inspects the contents of the WAD or its maps directly;
        instead it uses fill_pool to produce a suitable subset of the WAD which
        it can then inspect and manipulate.
        """
        locations = []
        for map in world.maps:
            # Just choose per map for now
            locations += map.choose_locations(world)
        pool = DoomPool(self, locations, world)
        return pool

    def items(self) -> List[DoomItem]:
        return self.items_by_name.values()

    def item(self, name: str) -> DoomItem:
        return self.items_by_name[name]

    def is_doom(self) -> bool:
        types = {i.typename for i in self.items()}
        return (
            'Chainsaw' in types
            or 'ripsaw' in types # FreeDoom 1/2
            # Just in case the wad doesn't have a chainsaw
            or 'Soulsphere' in types
            or 'GreenArmor' in types)

    def is_heretic(self) -> bool:
        types = {i.typename for i in self.items()}
        return (
            'ArtiTomeOfPower' in types
            or 'GoldWandHefty' in types)

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
        # Register 'Health' on all maps since it's used as a placeholder in
        # pretuning mode. It's one of the gzDoom base classes so we know it'll
        # always be available.
        self.register_item(None,
            DoomItem(map=None, category="small-health", typename="Health", tag="Health"))
        access_token = self.register_item(None,
            DoomItem(map=map.map, category="token", typename="GZAP_LevelAccess", tag="Level Access"))
        map.add_loose_item(access_token.name())

        automap_token = self.register_item(None,
            DoomItem(map=map.map, category="token", typename="GZAP_Automap", tag="Automap"))
        map.add_loose_item(automap_token.name())

        clear_token = self.register_item(None,
            DoomItem(map=map.map, category="token", typename="", tag="Level Clear"))
        map_exit = DoomLocation(self, map=map.map, item=clear_token, secret=False, json=None)
        # TODO: there should be a better way of overriding location names
        map_exit.item_name = "Exit"
        map_exit.item = clear_token
        map_exit.orig_item = None
        self.register_location(map_exit, {1,2,3})

    def new_item(self, json: Dict[str,str]) -> None:
        """
        Add a new item to the item pool, and its position to the location pool.

        If it's a new kind of item, we allocate an ID for it and create an entry in the item table. Otherwise
        we just increment the count on the existing entry. The item's location is added to the location pool
        using the item's name as a disambiguator.
        """
        # Extract the position information for addition to the location table.
        map = json["map"]
        position = json.pop("position")
        skill = set(json.pop("skill", [1,2,3]))
        secret = json.pop("secret", False)

        # We add everything in the logic file to the pool. Not everything will
        # necessarily be used in randomization, but we need to do this at load
        # time, before we know what item categories the user has requested.
        item = self.register_item(map, DoomItem(**json))
        self.new_location(map, item, secret, skill, position)

    def register_item(self, map: str, item: DoomItem) -> DoomItem:
        if item.name() in self.items_by_name:
            return self.register_duplicate_item(map, item)

        # Initially items are stored as lists to handle duplicates.
        # During postprocessing, we disambiguate.
        self.items_by_name[item.name()] = [item]
        return item

    def register_duplicate_item(self, map: str, item: DoomItem) -> DoomItem:
        for other in self.items_by_name[item.name()]:
            if other == item:
                # An exact duplicate of this item is already known.
                return other

        self.items_by_name[item.name()].append(item)
        return item

    def disambiguate_duplicate_items(self):
        all_items = {}
        for items in self.items_by_name.values():
            dupes = len(items) > 1
            for item in items:
                if dupes:
                    item.disambiguate = True
                assert item.name() not in all_items,f"Error resolving item name collisions, item f{item} collides with distinct item f{all_items[item.name()]} even after trying to disambiguate."
                all_items[item.name()] = item
        self.items_by_name = all_items

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

    def new_secret(self, json: Dict[str, Any]) -> None:
        location = DoomLocation(self, map=json['map'], item=None, secret=True, json=None)
        location.item_name = f"Secret {json['sector']}"
        location.category = "secret-sector"
        location.sector = json['sector']
        skill = set(json.pop("skill", [1,2,3]))
        self.register_location(location, skill)

    def new_key(self, map: str, typename: str, scopename: str, cluster: int, maps: List[str]) -> None:
        """
        Register a key in the key table, along with information about which maps it's in.

        Key records will be matched up with key items at the end of the tuning pass.
        """
        key = DoomKey(typename, scopename, cluster, frozenset(maps))
        self.keys_by_name.setdefault(key.fqin(), key)

    def keys_for_map(self, mapname):
        return frozenset(
            key for key in self.keys_by_name.values()
            if mapname in key.maps)

    def reify_keys(self, mapname, keytypes):
        keys = frozenset(
            key for key in self.keys_for_map(mapname)
            if key.typename in keytypes)
        assert len(keys) == len(keytypes), f"Error reifying keys for {mapname}: wanted {keytypes}, but the logic only contains {[key.fqin() for key in keys]}"
        return keys

    def tune_location(self, id, name, keys=None, pos=None, unreachable=False) -> None:
        """
        Adjust the reachability rules for a location.

        This is emitted by the game when the player checks a location, and records
        what keys they had when this happened. This can be used to minimize the keyset
        for a given location.

        This needs to run after AP-SCAN-DONE so that the keysets are initialized,
        which shouldn't be a problem in practice unless people are assembling play
        logs out of order.
        """
        if pos is None:
            # Legacy tuning file, or location with no position (e.g. level exit
            # or secret sector).
            return self.tune_location_by_name(name, keys, unreachable)

        (map,x,y,z) = pos
        pos = DoomPosition(map=map, virtual=False, x=x, y=y, z=z)
        for loc in self.locations_at_position(pos):
            if unreachable:
                # print(f"Marking {loc.name()} as unreachable. {id(loc)}")
                loc.unreachable = True
            elif keys is not None:
                loc.tune_keys(self.reify_keys(map, keys))

    def tune_location_by_name(self, name, keys=None, unreachable=False) -> None:
        # Index by name rather than ID because the ID may change as more WADs
        # are added, but the name should not.
        locs = self.locations_by_name.get(name, [])
        if len(locs) == 0:
            # print(f"Tuning file contains info for nonexistent check {name}")
            return
        for loc in locs:
            if unreachable:
                # print(f"Marking {loc.name()} as unreachable. {id(loc)}")
                loc.unreachable = True
            elif keys is not None:
                # Before passing the keys to tune_keys, we need to annotate them with
                # the map name so that they match the names that Archipelago expects.
                # TODO: When we support keys with greater-than-one-map scope, this
                # gets more complicated. Probably we have some information supplied
                # earlier in the tuning file we use to do the conversion.
                loc.tune_keys(self.reify_keys(loc.pos.map, keys))

    def disambiguate_duplicate_locations(self) -> None:
        # Resolve name collisions among locations and register them with the logic.
        # We iterate the maps here, rather than locations_by_pos, because virtual
        # locations like exits don't appear in the position table but do appear
        # in their corresponding maps.
        for map in self.maps.values():
            self.disambiguate_in_map(map)

    def finalize_location(self, loc):
        self.locations_by_name.setdefault(loc.legacy_name(), []).append(loc)

    def bin_locations_by(self, locs, f) -> Dict[str, List[DoomMap]]:
        """
        "Rebin" a collection of locations based on a binning function.

        If all locations end up in unique bins, finalizes them and returns {}.

        Otherwise, returns a dict keyed by bin name where each value is the
        collection of locations in that bin.
        """
        bins = {}
        for loc in locs:
            bins.setdefault(f(loc), []).append(loc)
        for bin in bins.values():
            if len(bin) > 1:
                return { name: locs for name,locs in bins.items() }
        for bin in bins.values():
            self.finalize_location(bin[0])
        return {}

    def disambiguate_in_map(self, map) -> None:
        bb = BoundingBox()

        for loc in map.locations:
            bb.add_point(loc.pos)

        bins = self.bin_locations_by(map.locations, lambda loc: loc.name())

        # We do each bin separately, so that for a given name, we end up at the
        # same fallback for every location of that name, rather than (say) a mix
        # of coordinates for some soulspheres and compass directions for others.
        for bin in bins.values():
            if len(bin) == 1:
                self.finalize_location(bin[0])
            else:
                self.disambiguate_bin(bb, bin)

    def disambiguate_bin(self, bb, locs):
        # Bins contains all locations that had name collisions. First, try binning
        # by coarse direction and distance. In many maps this suffices for armour,
        # powerups, etc.
        def binner(loc):
            dir,dist = bb.position_name(loc.pos.x, loc.pos.y)
            oldname = loc.name()
            if dist:
                loc.disambiguation = f"{dir} {dist}"
            else:
                loc.disambiguation = dir
            # print(f"Renaming {oldname} -> {loc.name()}")
            return loc.name()

        bins = self.bin_locations_by(locs, binner)
        if len(bins) == 0:
            return

        # That didn't work, so try again with coordinates.
        def binner(loc):
            oldname = loc.name()
            loc.disambiguation = f"{int(loc.pos.x)},{int(loc.pos.y)}"
            # print(f"Renaming {oldname} -> {loc.name()}")
            return loc.name()

        bins = self.bin_locations_by([loc for bin in bins.values() for loc in bin], binner)
        if len(bins) == 0:
            return

        # If we get here, the binner couldn't fully disambiguate things even
        # with XY coordinates. At this point we commit anything that *could* be
        # disambiguated with XY, and then add Z coordinate to what's left.
        for bin in [bin for bin in bins.values() if len(bin) == 1]:
            self.finalize_location(bin[0])

        for loc in [loc for bin in bins.values() for loc in bin if len(bin) > 1]:
            oldname = loc.name()
            loc.disambiguation = f"{int(loc.pos.x)},{int(loc.pos.y)},{int(loc.pos.z)}"
            # print(f"Renaming {oldname} -> {loc.name()}")
            self.finalize_location(loc)

    def finalize_scan(self, json) -> None:
        """
        Do postprocessing after the initial scan is completed but before tuning.
        """
        self.disambiguate_duplicate_items()
        self.disambiguate_duplicate_locations()

    def finalize_all(self, logic) -> None:
        """
        Do postprocessing after all events have been ingested.
        """
        self.finalize_location_keysets()
        self.finalize_key_items()
        self.finalize_ids(logic)

    def finalize_location_keysets(self):
        """
        Set up the information needed for key-based logic checks at generation time by:
        - telling each map which keys exist in it, and
        - giving each location we don't have tuning data for a pessimal default keyset
        """
        for map in self.maps.values():
            keys = self.keys_for_map(map.map)
            map.keyset = keys
            for loc in map.locations:
                if loc.keys is None:
                    loc.keys = frozenset({keys})

    def finalize_key_items(self):
        """
        Match up DoomKey records with the underlying items.
        For simple keys (found during scan, one map) this is a no-op. For dynkeys
        it creates the missing key item. For dynamic multikeys it also subsumes
        all other keys that are just aspects of this one in different levels.
        """
        for key in self.keys_by_name.values():
            if key.fqin() in self.items_by_name:
                continue

            key_item = DoomItem(map=key.scopename, category="key", typename=key.typename, tag=key.typename)
            assert key_item.name() == key.fqin(), f"{key_item.name()} != {key.fqin()}"
            self.items_by_name[key.fqin()] = key_item

            # Any existing keys subsumed by this one should be replaced to point
            # to it. In particular, this means that if a location in the pool
            # contains "GreenKey (MAP04)" and that's subsumed by "GreenKey (EP1)",
            # adding that location to the pool will get you the latter.
            for mapname in key.maps:
                keyname = f"{key.typename} ({mapname})"
                if keyname in self.items_by_name:
                    self.items_by_name[keyname] = key_item

    def finalize_ids(self, logic):
        for item in self.items_by_name.values():
            logic.register_item(item)
        for locs in self.locations_by_name.values():
            for loc in locs:
                logic.register_location(loc)

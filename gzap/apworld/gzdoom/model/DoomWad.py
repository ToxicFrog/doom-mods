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
from typing import Any, Dict, List, Set, FrozenSet, Tuple, Iterable

from .BoundingBox import BoundingBox
from .DoomPool import DoomPool
from .DoomItem import DoomItem, DoomFlag
from .DoomLocation import DoomLocation
from .DoomPosition import DoomPosition, DoomCoordPosition, to_position
from .DoomMap import DoomMap
from .DoomKey import DoomKey
from .DoomRegion import DoomRegion


class DuplicateMapError(RuntimeError):
    """
    A logic file needs to contain one entry per map. Multiple difficulty levels
    are encoded into the individual locations.
    """
    pass


@dataclass
class DoomWad:
    name: str
    package: str | None  # Name of module this logic file was loaded from, or None if from disk
    maps: Dict[str,DoomMap] = field(default_factory=dict)
    items_by_name: Dict[str,DoomItem] = field(default_factory=dict) # Indexed by FQIN
    items_by_type: Dict[str,DoomItem] = field(default_factory=dict) # Indexed by typename
    # Map of skill -> position -> location used while importing locations.
    locations_by_pos: Dict[int,Dict[DoomPosition,DoomLocation]] = field(default_factory=dict)
    # Map of FQIN -> key record
    keys_by_name: Dict[str,DoomKey] = field(default_factory=dict)
    # Tuning data is being loaded, or has been loaded, for this wad.
    tuned: bool = False
    # Flags passed through from the tuning file
    flags: FrozenSet[str] = frozenset()
    # Implicit and explicit regions. Minimum one per map, but there might be more.
    regions: Dict[str,DoomRegion] = field(default_factory=dict)

    def __post_init__(self):
        self.locations_by_pos = {
            1: {},
            2: {},
            3: {},
        }

    def has_flag(self, flag):
        return flag in self.flags

    def use_hub_logic(self):
        return self.has_flag('use_hub_logic')

    def hub_logic_exits(self):
        assert self.use_hub_logic()
        return {
            map
            for flag in self.flags if flag.startswith('hub_logic_exits=')
            for map in flag.split('=')[1].split(',')
        }

    def all_locations(self) -> Iterable[DoomLocation]:
        return (loc for map in self.maps.values() for loc in map.locations)

    def locations_for_stats(self, skill: int) -> Iterable[DoomLocation]:
        skill = min(3, max(1, skill)) # clamp ITYTD->HNTR and N!->UV
        return (
            loc for map in self.maps.values() for loc in map.all_locations(skill, {})
            if loc.is_default_enabled()
        )

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
            locations += map.all_locations(world.spawn_filter, {})
        pool = DoomPool(self, locations, world)
        return pool

    def items(self) -> List[DoomItem]:
        return self.items_by_name.values()

    def item(self, name: str) -> DoomItem:
        return self.items_by_name[name]

    def placeholder_item(self) -> DoomItem:
        return self.items_by_name['Health']

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

        self.maps[map] = DoomMap(wad=self, **json)
        self.register_map_flags(self.maps[map])

    def register_map_flags(self, map: DoomMap):
        # Register 'Health' on all maps since it's used as a placeholder in
        # pretuning mode. It's one of the gzDoom base classes so we know it'll
        # always be available.
        self.register_item(
            DoomItem(map=None, category="small-health", typename="Health", tag="Health"))
        access_flag = self.register_item(
            DoomFlag(map=map.map, category="ap_flag-ap_level", typename="GZAP_LevelAccess", tag=map.access_flag_name()))
        map.add_loose_item(access_flag.name())

        automap_flag = self.register_item(
            DoomFlag(map=map.map, category="ap_flag-ap_map", typename="GZAP_Automap", tag=map.automap_name()))
        map.add_loose_item(automap_flag.name())

        if self.use_hub_logic():
            # In hub mode, we create one victory flag and one exit per cluster,
            # rather than one per map.
            if map.map not in self.hub_logic_exits():
                return

        clear_flag = self.register_item(
            DoomFlag(map=map.map, category="ap_flag-ap_victory", typename="GZAP_VictoryFlag", tag=map.clear_flag_name()))
        map_exit = DoomLocation(self, item=clear_flag, secret=False, pos=[map.map,'event','exit'])

        # TODO: there should be a better way of overriding location names
        map_exit.item_name = "Exit"
        map_exit.item = clear_flag
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
        pos = json.pop("pos")
        skill = set(json.pop("skill", [1,2,3]))
        secret = json.pop("secret", False)
        name = json.pop("name", None)
        tid = json.pop("tid", None)

        # We add everything in the logic file to the pool. Not everything will
        # necessarily be used in randomization, but we need to do this at load
        # time, before we know what item categories the user has requested.
        item = self.register_item(DoomItem(pos[0], **json))
        self.new_location(item, secret, skill, pos, name)

    def register_item(self, item: DoomItem) -> DoomItem:
        assert not self.tuned, f"AP-ITEM found in tuning data for {self.name} -- make sure you don't have a logic file mixed in with the tuning."

        if item.name() in self.items_by_name:
            return self.register_duplicate_item(item)

        # Initially items are stored as lists to handle duplicates.
        # During postprocessing, we disambiguate.
        self.items_by_name[item.name()] = [item]
        return item

    def register_duplicate_item(self, item: DoomItem) -> DoomItem:
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
        self.items_by_type = { item.typename: item for item in self.items() }

    def define_region(self, map: str, keys: List[str], region: str = None):
        if not region:
            self.maps[map].extra_rules.record_tuning(keys)
        else:
            name = f'{map}/{region}'
            self.regions.setdefault(name, DoomRegion(map, region)).record_tuning(keys)

    def regions_in_map(self, map: str):
        return (r for r in self.regions.values() if r.map == map)

    def new_location(self, item: DoomItem, secret: bool, skill: Set[int], pos: List[Any], name: str) -> None:
        """
        Add a new location to the location pool.

        Items are uniquely identified by their position (xyz coordinates, or
        sector, TID, or event association) and skill level. If multiple
        locations have the same position (i.e. the mapper placed multiple items
        exactly on top of each other) they will be coalesced into a single
        position, and if they have different items in them it is unspecified
        which one "wins".
        """
        location = DoomLocation(self, item, secret, pos, name)
        self.register_location(location, skill)

    def register_location(self, location: DoomLocation, skill: Set[int]) -> None:
        assert not self.tuned, f"AP-LOCATION found in tuning data for {self.name} -- make sure you don't have a logic file mixed in with the tuning."

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
        assert not self.tuned, f"AP-SECRET found in tuning data for {self.name} -- make sure you don't have a logic file mixed in with the tuning."
        location = DoomLocation(self, item=None, secret=True, pos=json['pos'], custom_name=json.get('name', None))
        if location.pos.secret_type == 'sector':
            location.item_name = f"Secret {location.pos.secret_id}"
            location.categories = frozenset({'secret', 'sector'})
        else:
            location.item_name = f"Secret T{location.pos.secret_id}"
            location.categories = frozenset({'secret', 'marker'})

        skill = set(json.pop("skill", [1,2,3]))
        self.register_location(location, skill)

    def new_key(self, tag: str, typename: str, scopename: str, cluster: int, maps: List[str]) -> None:
        """
        Register a key in the key table, along with information about which maps it's in.

        Key records will be matched up with key items at the end of the tuning pass.
        """
        assert not self.tuned, f"AP-KEY found in tuning data for {self.name}. If this is a legitimate tuning file, this usually means tuning found keys that the scanner missed -- please find the AP-KEY messages in the tuning file and move them to the matching logic file."
        key = DoomKey(tag, typename, scopename, cluster, frozenset(maps))
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

    def record_tuning(self, locs, keys, region, unreachable):
        for loc in locs:
            loc.record_tuning(keys, region, unreachable)

    def tune_location(self, id, name, pos, keys=None, region=None, unreachable=None) -> None:
        """
        Adjust the reachability rules for a location.

        This is emitted by the game when the player checks a location, and records
        what keys they had when this happened. This can be used to minimize the keyset
        for a given location.

        This needs to run after AP-SCAN-DONE so that the keysets are initialized,
        which shouldn't be a problem in practice unless people are assembling play
        logs out of order.
        """
        if unreachable is None and keys is None and region is None:
            return

        pos = to_position(*pos)
        self.record_tuning(self.locations_at_position(pos), keys, region, unreachable)

    def disambiguate_duplicate_locations(self) -> None:
        # Resolve name collisions among locations and register them with the logic.
        # We iterate the maps here, rather than locations_by_pos, because virtual
        # locations like exits don't appear in the position table but do appear
        # in their corresponding maps.
        for map in self.maps.values():
            self.disambiguate_in_map(map)

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
        return {}

    def disambiguate_in_map(self, map) -> None:
        bb = BoundingBox()

        for loc in map.locations:
            if type(loc.pos) is DoomCoordPosition:
                bb.add_point(loc.pos)

        bins = self.bin_locations_by(map.locations, lambda loc: loc.name())

        # We do each bin separately, so that for a given name, we end up at the
        # same fallback for every location of that name, rather than (say) a mix
        # of coordinates for some soulspheres and compass directions for others.
        for bin in bins.values():
            if len(bin) > 1:
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
        # with XY coordinates. Add a Z coordinate to anything that's left.
        for loc in [loc for bin in bins.values() for loc in bin if len(bin) > 1]:
            oldname = loc.name()
            loc.disambiguation = f"{int(loc.pos.x)},{int(loc.pos.y)},{int(loc.pos.z)}"
            # print(f"Renaming {oldname} -> {loc.name()}")

    def finalize_logic(self, logic) -> None:
        """
        Do postprocessing after the initial scan is completed but before tuning.

        At this point all IDs need to be defined and all items reified, but
        we don't need complete reachability information.
        """
        self.disambiguate_duplicate_items()
        self.disambiguate_duplicate_locations()
        self.finalize_key_items()
        self.finalize_ids(logic)

    def finalize_tuning(self) -> None:
        """
        Do postprocessing after all events have been ingested, including tuning.
        """
        for loc in self.all_locations():
            loc.finalize_tuning()
        for name,region in self.regions.items():
            region.finalize_tuning(default=[])
        for map in self.maps.values():
            map.extra_rules.finalize_tuning(default=[])

    def finalize_key_items(self):
        """
        Hook up DoomKeys with their underlying items and corresponding maps.

        For simple keys (one-map scope, found during scan), we just add the key
        to the map's keyset (so we can easily look it up by map later) and we're
        done.

        For dynkeys (found during tuning) and multikeys (multi-map scope), it
        creates a new DoomItem representing the key, links the key to it, and
        replaces any item table entries for single-map versions of the same
        actual key with references to the newly created multikey item.
        """
        for key in self.keys_by_name.values():
            for mapname in key.maps:
                self.maps[mapname].keyset.add(key)

            if key.fqin() in self.items_by_name:
                continue

            key_item = DoomItem(map=key.scopename, category="key", typename=key.typename, tag=key.tag)
            assert key_item.name() == key.fqin(), f"{key_item.name()} != {key.fqin()}"
            self.items_by_name[key.fqin()] = key_item

            # Any existing keys subsumed by this one should be replaced to point
            # to it. In particular, this means that if a location in the pool
            # contains "GreenKey (MAP04)" and that's subsumed by "GreenKey (EP1)",
            # adding that location to the pool will get you the latter.
            for mapname in key.maps:
                keyname = f"{key.tag} ({mapname})"
                if keyname in self.items_by_name:
                    self.items_by_name[keyname] = key_item

    def finalize_ids(self, logic):
        for item in self.items_by_name.values():
            logic.register_item(item)
        for loc in self.all_locations():
            logic.register_location(loc)

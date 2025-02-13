import settings
import Utils
import json
import os
from dataclasses import dataclass, field, InitVar
from typing import Dict, List, NamedTuple, Optional, Set

from .model.DoomItem import DoomItem
from .model.DoomLocation import DoomLocation, DoomPosition


class Mapinfo(NamedTuple):
    """Information about a map used to generate the MAPINFO lump."""
    levelnum: int
    cluster: int
    title: str
    is_lookup: bool
    music: str
    music_track: int
    sky1: str
    sky1speed: float
    sky2: str
    sky2speed: float
    flags: List[str]

# Map metadata. Lump name, user-facing title, secrecy bit, and which keys, if
# any, the map contains.
@dataclass
class WadMap:
    map: str
    # Item IDs for the various tokens that unlock or mark the level as finished
    access_id: int
    automap_id: int
    clear_id: int
    exit_id: int
    # JSON initializer for the mapinfo
    info: InitVar[Dict]
    # Data for the MAPINFO lump
    mapinfo: Optional[Mapinfo] = None
    # Key and weapon information for computing access rules
    keyset: Set[DoomItem] = field(default_factory=set)
    gunset: Set[DoomItem] = field(default_factory=set)
    # All locations contained in this map
    locations: List[DoomLocation] = field(default_factory=list)

    def __post_init__(self, info):
        self.mapinfo = Mapinfo(**info)

    def access_rule(self, player):
        def rule(state):
            if not state.has(self.access_token_name(), player):
                return False

            # We need at least half of the non-secret guns in the level,
            # rounded down, to give the player a fighting chance.
            player_guns = { item.name for item in self.gunset if state.has(item.name, player) }
            if len(player_guns) < len(self.gunset)//2:
                return False

            return True

        return rule

    def access_token_name(self):
        return f"Level Access ({self.map})"

    def clear_token_name(self):
        return f"Level Clear ({self.map})"


class DuplicateMapError(RuntimeError):
    pass

class WadInfo:
    last_id: int = 0
    skill: int
    maps: Dict[str,WadMap] = {}
    items_by_name: Dict[str,DoomItem] = {}
    locations_by_name: Dict[str,DoomLocation] = {}
    locations_by_pos: Dict[DoomPosition,DoomLocation] = {}
    first_map: WadMap | None = None

    def get_id(self) -> int:
        self.last_id += 1
        return self.last_id

    def all_maps(self) -> List[WadMap]:
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
        print(json)
        if map not in self.maps:
            self.maps[map] = WadMap(
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


def get_wadinfo_path(file_name: str = "") -> str:
    options = settings.get_settings()
    if not file_name:
        file_name = options["gzdoom_options"]["wad_info_file"]
    if not os.path.exists(file_name):
        file_name = Utils.user_path(file_name)
    return file_name


class UnsupportedScanEventError(NotImplementedError):
    pass

def get_wadinfo(file_name: str = "") -> WadInfo:
    info: WadInfo = WadInfo()
    print("Loading logic from", get_wadinfo_path(file_name))
    with open(get_wadinfo_path(file_name), "r") as fd:
        for line in fd:
            if not line.startswith("AP-"):
                continue

            [evt, payload] = line.split(" ", 1)
            payload = json.loads(payload)
            print(evt, payload)
            if evt == "AP-MAP":
                info.new_map(payload)
            # elif evt == "AP-MAPINFO-START":
            #     # everything from here to AP-MAPINFO-END is the MAPINFO lumps
            elif evt == "AP-ITEM":
                info.new_item(payload)
            elif evt == "AP-SCAN-DONE":
                info.finalize_scan(payload)
            elif evt == "AP-CHECK":
                info.tune_location(**payload)
            elif evt in {"AP-XON", "AP-ACK"}:
                # used only for multiplayer
                pass
            else:
                # Unsupported event type
                raise UnsupportedScanEventError(evt)

    info.finalize_all()
    return info

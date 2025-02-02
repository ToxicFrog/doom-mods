import settings
import Utils
import json
import os
from typing import Any, Dict, List, NamedTuple, Set
from BaseClasses import ItemClassification

# A Doom position -- 3d coordinates + yaw.
# Pitch and roll are also used in gzDoom but are almost never useful to us, so
# we don't store them.
# This is used at generation time to detect duplicate Locations, and at runtime
# to match up Locations with Actors.
class WadPosition(NamedTuple):
    x: float
    y: float
    z: float
    angle: float


class WadItem:
    """
    A (potentially randomizeable) item in the WAD.

    Most items only get one of these -- i.e. all GreenArmors are represented by
    a single WadItem with >1 count. Exceptions are items that are scoped to the
    level they're found in, like keycards; those get a different WadItem for
    each level they appear in.
    """
    id: int        # AP item ID, assigned by the caller
    category: str  # Randomization category (e.g. key, weapon)
    typename: str  # gzDoom class name
    tag: str       # User-visible name *in gzDoom*
    name: str      # User-visible name *in Archipelago*
    count: int     # How many are in the item pool

    def __init__(self, map, category, typename, tag):
        self.category = category
        self.typename = typename
        self.tag = tag
        self.count = 1
        if category == "key" or category == "map" or category == "token":
            self.name = f"{tag} ({map})"
        else:
            # Potential problem here -- what if we have multiple classes with
            # the same tag?
            self.name = tag

    def __str__(self) -> str:
        return f"WadItem#{self.id}({self.typename} as {self.name})"

    __repr__ = __str__

    def classification(self) -> ItemClassification:
        if self.category == "key" or self.category == "token" or self.category == "weapon":
            return ItemClassification.progression
        elif self.category == "map" or self.category == "upgrade":
            return ItemClassification.useful
        else:
            return ItemClassification.filler

    def can_replace(self) -> bool:
        """True if locations holding items of this type should be eligible as randomization destinations."""
        return (
            self.category == "key"
            or self.category == "weapon"
            or self.category == "map"
            or self.category == "upgrade"
            or self.category == "powerup"
            or self.category == "big-armor"
            or self.category == "big-health"
            or self.category == "tool"
        )


class WadLocation:
    """
    A location we can perhaps randomize items into.

    A WAD location is defined primarily by its position; you cannot have multiple locations with the
    same position. They are *named*, however, based on their enclosing map and the item they originally
    contained, e.g. "MAP02 - BlueCard" or "MAP03 - Blursphere".

    If multiple copies of the same item appear in a map, the later copies are disambiguated by internal
    ID. This isn't great; ideally, we'd have an end-of-map-loading pass that computes the center of the
    map based on bounding box, then disambiguates based on compass direction and distance relative to
    center.
    """
    id: int
    name: str
    category: str
    map: str
    secret: bool = False
    pos: WadPosition | None = None
    keyset: Set[WadItem]
    item: WadItem | None = None  # Used for place_locked_item

    def __init__(self, map: str, item: WadItem, json: str | None):
        self.name = f"{map} - {item.tag}"  # Caller will deduplicate if needed
        self.category = item.category
        self.map = map
        self.keyset = set()
        if json:
            self.secret = json["secret"]
            del json["secret"]
            self.pos = WadPosition(**json)

    def __str__(self) -> str:
        return f"WadLocation#{self.id}({self.name} @ {self.pos} % {self.keyset})"

    __repr__ = __str__

    def access_rule(self, player):
        return lambda state: [
            state.has(k.name, player)
            for k in self.keyset
        ].count(False) == 0


# Map metadata. Lump name, user-facing title, secrecy bit, and which keys, if
# any, the map contains.
class WadMap(NamedTuple):
    map: str
    title: str
    secret: bool
    skill: int
    keyset: Set[WadItem]
    locations: List[WadLocation]

    # TODO: we should also take weapons into account here, with harder levels
    # expecting the player to have more/bigger guns, or perhaps basing it on
    # what items would normally be found in non-secret places in the level.
    def access_rule(self, player):
        return lambda state: state.has(self.access_token_name(), player)

    def access_token_name(self):
        return f"Level Access ({self.map})"

    def clear_token_name(self):
        return f"Level Clear ({self.map})"


class WadInfo:
    last_id = 0
    maps: Dict[str,WadMap] = {}
    items_by_name: Dict[str,WadItem] = {}
    locations_by_name: Dict[str,WadLocation] = {}
    locations_by_pos: Dict[WadPosition,WadLocation] = {}
    first_map: WadMap | None = None

    def get_id(self) -> int:
        self.last_id += 1
        return self.last_id

    def starting_items(self) -> List[WadItem]:
        return [
            self.items_by_name[self.first_map.access_token_name()]
        ] + list(self.first_map.keyset)

    def new_mapinfo(self, json: Dict[str,str]) -> None:
        # TODO: in refinement mode, we need to check that the skill level being
        # played is the same as what was originally scanned.
        map = json["map"]
        if map not in self.maps:
            self.maps[map] = WadMap(keyset=set(), locations=[], **json)
        else:
            self.maps[map].title = json["title"]
            self.maps[map].secret = json["secret"]

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

        # Provisionally create a WadItem.
        item = WadItem(**json)
        # Do we actually care about these? If not, don't generate an ID for this item or add it to the pool,
        # and don't consider its location as a valid randomization destination.
        if not item.can_replace():
            return

        self.add_item(map, item)
        self.new_location(map, item, position)

    def add_item(self, map: str, item: WadItem) -> None:
        # If we haven't seen this kind of item before, give it an ID and put
        # it in the lookup table, otherwise update the count for the existing
        # WadItem.
        if item.name not in self.items_by_name:
            item.id = self.get_id()
            self.items_by_name[item.name] = item
        else:
            item = self.items_by_name[item.name]
            item.count += 1

        if item.category == "key":
            self.maps[map].keyset.add(item)


    def new_location(self, map: str, item: WadItem, json: Dict[str, str]) -> None:
        """
        Add a new location to the location pool.

        If it is identical (same position) as an existing location, it is silently dropped. This is,
        fortunately, rare. If multiple locations share the same position but have different items,
        all of their items are added to the pool but it's undefined which one the location is named
        after and inherits the item category from.
        """
        location = WadLocation(map, item, json)

        if location.pos in self.locations_by_pos:
            # Duplicate location; ignore it
            return

        self.add_location(location)

    def add_location(self, location: WadLocation) -> None:
        # Caller has already done position duplicate checking
        location.id = self.get_id()
        if location.name in self.locations_by_name:
            location.name = f"{location.name} <{location.id}>"

        self.maps[location.map].locations.append(location)
        self.locations_by_name[location.name] = location
        if location.pos:
            self.locations_by_pos[location.pos] = location

    def finalize_scan(self) -> None:
        """
        Do postprocessing after the initial scan is completed but before play-guided refinement, if any.

        At the moment this means creating the synthetic level-exit and level-cleared locations and items,
        then pessimistically initializing the keyset for each location to match the keys of the enclosing map.
        """
        for map in self.maps:
            map_access = WadItem(map=map, category="token", typename="GZAP_LevelAccessToken", tag="Level Access")
            map_clear = WadItem(map=map, category="token", typename="GZAP_LevelClearToken", tag="Level Clear")
            map_exit = WadLocation(map, map_clear, None)
            map_exit.item = map_clear
            map_exit.name = f"{map} - Exit"
            self.add_item(map, map_access)
            self.add_item(map, map_clear)
            self.add_location(map_exit)

        for loc in self.locations_by_name.values():
            loc.keyset = self.maps[loc.map].keyset.copy()


    def finalize_all(self) -> None:
        """
        Do postprocessing after all events have been ingested.

        This computes the region-to-location map for each level based on the final keysets.
        """
        pass
        # for loc in self.locations_by_name.values():
        #     map = self.maps[loc.map]
        #     map.locations.append(loc)
            # if loc.keyset not in map.regions:
            #     map.regions[loc.keyset] = set()
            # map.regions[loc.keyset].add(loc)


def get_wadinfo_path(file_name: str = "") -> str:
    options = settings.get_settings()
    if not file_name:
        file_name = options["gzdoom_options"]["wad_info_file"]
    if not os.path.exists(file_name):
        file_name = Utils.user_path(file_name)
    return file_name


def get_wadinfo(file_name: str = "") -> WadInfo:
    info: WadInfo = WadInfo()
    with open(get_wadinfo_path(file_name), "r") as fd:
        for line in fd:
            if not line.startswith("AP-"):
                continue

            [evt, payload] = line.split(" ", 1)
            payload = json.loads(payload)
            print(evt, payload)
            if evt == "AP-MAPINFO":
                info.new_mapinfo(payload)
            elif evt == "AP-ITEM":
                info.new_item(payload)
            elif evt == "AP-SCAN-DONE":
                info.finalize_scan()
            else:
                # Unsupported event type
                raise

    info.finalize_all()
    return info

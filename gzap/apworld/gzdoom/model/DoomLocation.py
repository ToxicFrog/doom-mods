from typing import NamedTuple, Optional, Set

from . import DoomItem

# A Doom position -- 3d coordinates + yaw.
# Pitch and roll are also used in gzDoom but are almost never useful to us, so
# we don't store them.
# This is used at generation time to detect duplicate Locations, and at runtime
# to match up Locations with Actors.
class DoomPosition(NamedTuple):
    """
    A Doom playsim position.

    This is a direct copy of the `pos` field of an Actor, plus the yaw angle (named
    `angle` to match gzDoom). Pitch and roll are almost never used so we don't bother
    with them here.
    """
    x: float
    y: float
    z: float
    # TODO: is angle even useful? We don't use it for anything right now.
    angle: float


class DoomLocation:
    """
    A location we can perhaps randomize items into.

    The primary key for a location is its enclosing map and its position. We cannot
    have two locations at the same place in the same map. If we get multiple items
    in the import at the same position, the first one generates a location, while
    the others are used only for item pool purposes.

    The location name -- which needs to be unique within the apworld for AP's internals
    to function, and which is also user-facing -- is currently drawn from the name of
    the enclosing map, plus the name of the item that originally occupied that location.

    If multiple locations in a map had the same item -- which is not uncommon, especially
    in larger levels -- later copies are disambiguated by appending the internal ID.
    TODO: do something more useful, like appending a compass direction relative to the
    center of the map or relative to the nearest entirely-unique item.
    """
    id: Optional[int] = None
    name: str
    category: str
    map: str
    secret: bool = False
    pos: DoomPosition | None = None
    keyset: Set[DoomItem]
    item: DoomItem | None = None  # Used for place_locked_item
    parent = None
    orig_item = None

    def __init__(self, parent, map: str, item: DoomItem, json: str | None):
        self.name = f"{map} - {item.tag}"  # Caller will deduplicate if needed
        self.category = item.category
        self.map = map
        self.keyset = set()
        self.parent = parent
        self.orig_item = item.name
        if json:
            self.secret = json["secret"]
            del json["secret"]
            self.pos = DoomPosition(**json)

    def __str__(self) -> str:
        return f"WadLocation#{self.id}({self.name} @ {self.pos} % {self.keyset})"

    __repr__ = __str__

    def tune_keys(self, keys):
        if keys < self.keyset:
            print(f"Keyset: {self.name} {self.keyset} -> {keys}")
            self.keyset = keys

    def access_rule(self, player):
        # TODO: in a really gross hack here, we assume that checks in the first
        # map are always accessible no matter what guns/keys you have, because
        # the former (hopefully) doesn't matter for the first map and the latter
        # are granted to you as starting inventory.
        if self.parent.maps[self.map] == self.parent.first_map:
            return lambda _: True
        # Otherwise, it's accessible if:
        # - you have all the keys for the map
        #     OR the map only has one key, and this is it
        # - AND you have at least half of the non-secret guns from this map.
        def rule(state):
            map = self.parent.maps[self.map]
            map_keys = { item.name for item in self.keyset }
            player_keys = { item for item in map_keys if state.has(item, player) }

            # Are we missing any keys?
            if player_keys < self.keyset:
                # If so, we might still be able to reach the location, if
                # - the map only has one key, and
                # - this is the location where that key would normally be found
                if {self.orig_item} == map_keys:
                    # print(f"Access granted: {self.name} (single key location)")
                    return True
                else:
                    # print(f"Access denied: {self.name}: want { {k.name for k in self.keyset} }, have {player_keys}")
                    return False

            # print(f"Access granted: {self.name}")
            return True

        return rule

"""
Data model for the locations items are found at in the WAD.
"""

from typing import NamedTuple, Optional, Set

from . import DoomItem

class DoomPosition(NamedTuple):
    """
    A Doom playsim position.

    This is a direct copy of the `pos` field of an Actor, plus the name of the
    containing map (so we don't consider two locations with the same coordinates
    but in different maps to actually be identical).
    """
    map: str
    virtual: bool  # True if this doesn't actually exist in the world and coords are meaningless
    x: float
    y: float
    z: float


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

    At generation time, each DoomLocation results in exactly one AP Location.
    """
    id: Optional[int] = None
    item_name: str # name of original item, used to name this location
    category: str
    pos: DoomPosition | None = None
    keyset: Set[DoomItem]
    item: DoomItem | None = None  # Used for place_locked_item
    parent = None
    orig_item = None
    disambiguate: bool = False

    def __init__(self, parent, map: str, item: DoomItem, json: str | None):
        self.category = item.category
        self.keyset = set()
        self.parent = parent
        self.orig_item = item
        self.item_name = item.tag
        if json:
            self.pos = DoomPosition(map=map, virtual=False, **json)
        else:
            self.pos = DoomPosition(map=map, virtual=True, x=0, y=0, z=0)

    def __str__(self) -> str:
        return f"DoomLocation#{self.id}({self.name()} @ {self.pos} % {self.keyset})"

    __repr__ = __str__

    def name(self) -> str:
        name = f"{self.pos.map} - {self.item_name}"
        if self.disambiguate:
            # TODO: we should figure out the bounding box of the map or nearby
            # unique items like keys and then give a compass direction instead
            name += f" [{int(self.pos.x)},{int(self.pos.y)}]"
        return name

    def tune_keys(self, keys):
        if keys < self.keyset:
            print(f"Keyset: {self.name} {self.keyset} -> {keys}")
            self.keyset = keys

    def access_rule(self, player):
        # A location is accessible if:
        # - you have access to the map (already checked at the region level)
        # - AND
        #   - either you have all the keys for the map
        #   - OR the map only has one key, and this is it
        def rule(state):
            player_keys = { item for item in self.keyset if state.has(item, player) }

            # Are we missing any keys?
            if player_keys < self.keyset:
                # If so, we might still be able to reach the location, if this
                # location is the map's only key (and thus must be accessible to
                # a player entering the map without keys).
                if {self.orig_item.name()} == self.keyset:
                    # print(f"Access granted: {self.name} (single key location)")
                    return True
                else:
                    # print(f"Access denied: {self.name}: want { {k.name for k in self.keyset} }, have {player_keys}")
                    return False

            # print(f"Access granted: {self.name}")
            return True

        return rule

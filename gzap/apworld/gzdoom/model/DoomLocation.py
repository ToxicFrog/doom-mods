"""
Data model for the locations items are found at in the WAD.
"""

from typing import NamedTuple, Optional, Set, List, FrozenSet, Collection

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
    x: int
    y: int
    z: int

    def as_vec3(self):
        return f"({self.x},{self.y},{self.z})"


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
    in larger levels -- all the locations with name collisions are disambiguated
    using their X,Y coordinates.

    At generation time, each DoomLocation results in exactly one AP Location.
    """
    id: Optional[int] = None
    item_name: str  # name of original item, used to name this location
    category: str
    pos: DoomPosition | None = None
    # Minimal sets of keys needed to access this location.
    # Initially None. Tuning data is used to initialize and refine this.
    # At the end of tuning, if still None, is replaced with a pessimal value;
    # this is done at the end of tuning to account for AP-KEYs that are only
    # detected during the tuning process.
    keys: Optional[FrozenSet[FrozenSet[str]]]
    item: DoomItem | None = None  # Used for place_locked_item
    parent = None  # The enclosing DoomWad
    orig_item = None
    disambiguation: str = None
    skill: Set[int]
    unreachable: bool = False
    secret: bool = False
    sector: int = 0

    def __init__(self, parent, map: str, item: DoomItem, secret: bool, json: str | None):
        self.keys = None
        self.parent = parent
        if item:
            # If created without an item it is the caller's responsibility to fill
            # in these fields post hoc.
            self.category = item.category
            self.orig_item = item
            self.item_name = item.tag
        self.skill = set()
        self.secret = secret
        if json:
            self.pos = DoomPosition(map=map, virtual=False, **json)
        else:
            self.pos = DoomPosition(map=map, virtual=True, x=0, y=0, z=0)

    def __str__(self) -> str:
        return f"DoomLocation#{self.id}({self.name()} @ {self.pos} % {self.keys})"

    __repr__ = __str__

    def name(self) -> str:
        name = f"{self.pos.map} - {self.item_name}"
        if self.disambiguation:
            name += f" [{self.disambiguation}]"
        return name

    def legacy_name(self) -> str:
        """
        Returns the name this location would have had in version 0.3.x and earlier.
        Used to match up locations to entries in legacy tuning files.
        """
        name = f"{self.pos.map} - {self.item_name}"
        if self.disambiguation:
            name += f" [{int(self.pos.x)},{int(self.pos.y)}]"
        return name

    def fqin(self, item: str) -> str:
        """Return the fully qualified item name for an item scoped to this location's map."""
        return f"{item} ({self.pos.map})"

    def tune_keys(self, new_keyset: FrozenSet[str]):
        # If this location was previously incorrectly marked unreachable,
        # correct it.
        # self.unreachable = False

        # If the new keyset is empty this is trivially reachable.
        if not new_keyset:
            # print(f"Tuning keys [{self.name()}]: old={self.keys} new=none")
            self.keys = frozenset()

        # If our existing keyset is empty, it cannot be further tuned.
        if self.keys == frozenset():
            return

        # Update the keysets by removing any keysets that this one is a proper
        # subset of.
        if self.keys is None:
            self.keys = frozenset()

        new_keys = frozenset({ks for ks in self.keys if not new_keyset < ks} | {new_keyset})

        if new_keys != self.keys:
            # print(f"Tuning keys [{self.name()}]: old={self.keys} tune={new_keyset} new={new_keys}")
            self.keys = new_keys

    def access_rule(self, world):
        # print(f"access_rule({self.name()}): keys={self.keys}")
        # A location is accessible if:
        # - you have access to the map (already checked at the region level)
        # - AND
        #   - either you have all the keys for the map
        #   - OR the map only has one key, and this is it
        def player_has_keys(state, keyset):
            player_keys = { key for key in keyset if state.has(key.fqin(), world.player) }
            # print(f"player_has_keys? {player_keys} >= {keyset}")
            return player_keys >= keyset

        def rule(state):
            if hasattr(world.multiworld, "generation_is_fake"):
                # If Universal Tracker is generating, pretend that locations
                # with the unreachable flag are unreachable always, so they
                # don't show up in the tracker.
                if self.unreachable:
                    return False
                # Also consider everything unreachable in pretuning mode, because
                # in pretuning the idea of "logic" kind of goes out the window
                # entirely.
                if world.options.pretuning_mode:
                    return False

            # Skip all checks in pretuning mode -- we know that the logic is
            # beatable because it's the vanilla game.
            if world.options.pretuning_mode:
                return True

            # If this location requires no keys, trivially succeed.
            if not self.keys:
                return True

            # Does the player have any of the sets of keys that grant access
            # to this location?
            for keyset in self.keys:
                if player_has_keys(state, keyset):
                    return True

            # If not, they might still be able to reach the location, if this
            # location is the map's only key (and thus must be accessible to
            # a player entering the map without keys).
            # This applies only if this is the only instance of that key in the
            # level; if the level has multiple copies of the same key, we don't
            # know which one is reachable first.
            if self.category == "key" and self.parent.get_map(self.pos.map).has_one_key(self.orig_item.name()):
                return True

            return False

        return rule

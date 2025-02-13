from typing import Optional
from BaseClasses import ItemClassification


class DoomItem:
    """
    A (potentially randomizeable) item in the WAD.

    Items which are not specific to a map, like ammo and weapons, get a single
    DoomItem instance with a single ID; the `count` field is used to keep track
    of how many are in the game.

    Items which are specific to a map, like automaps and keys, get a separate
    DoomItem for each map they appear in.

    The item name -- which must be unique within the apworld -- is currently
    derived from the item tag, as well as the map for per-map items.
    """
    id: Optional[int] = None        # AP item ID, assigned by the caller
    category: str  # Randomization category (e.g. key, weapon)
    typename: str  # gzDoom class name
    tag: str       # User-visible name *in gzDoom*
    name: str      # User-visible name *in Archipelago*
    count: int     # How many are in the item pool
    map: Optional[str]

    def __init__(self, map, category, typename, tag):
        self.category = category
        self.typename = typename
        self.tag = tag
        self.count = 1
        if category == "key" or category == "map" or category == "token":
            self.map = map
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
            # TODO: we only need one of each weapon for progression. So we should
            # treat them the same as, say, power bombs in SM: the first one is
            # progression, all the rest are filler.
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
            or self.category == "big-ammo"
            or self.category == "tool"
        )

    # TODO: consider how this interacts with ammo more. Possibly we want to keep
    # big-ammo in the world where it falls, but add some big and medium ammo to
    # the item pool as filler?
    def should_include(self) -> bool:
        """True if this item should be included in the pool."""
        return self.can_replace() and self.category != "map"


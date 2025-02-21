"""
Data model for items (or rather, item types) in Doom.
"""

from typing import Optional, Set, Dict
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

    At generation time, each AP Item is derived from a DoomItem in a many-to-one
    relationship.
    """
    id: Optional[int] = None        # AP item ID, assigned by the caller
    category: str           # Randomization category (e.g. key, weapon)
    typename: str           # gzDoom class name
    tag: str                # User-visible name *in gzDoom*
    count: Dict[int,int]    # How many are in the item pool on each skill
    map: Optional[str] = None
    disambiguate: bool = False

    def __init__(self, map, category, typename, tag, skill=[]):
        self.category = category
        self.typename = typename
        self.tag = tag
        self.count = { sk: 1 for sk in skill }
        # TODO: caller should specify this
        if category == "key" or category == "map" or category == "token":
            self.map = map

    def __str__(self) -> str:
        if self.count > 1:
            return f"DoomItem#{self.id}({self.name()})×{self.count}"
        else:
            return f"DoomItem#{self.id}({self.name()})"

    __repr__ = __str__

    def __eq__(self, other) -> bool:
        return self.tag == other.tag and self.map == other.map

    def update_skill_from(self, other) -> None:
        for sk,count in other.count.items():
            self.count[sk] = self.count.get(sk, 0) + count

    def set_max_count(self, count: int):
        for sk,n in self.count.items():
            self.count[sk] = min(n, count)

    def name(self) -> str:
        """Returns the user-facing Archipelago name for this item."""
        name = self.tag
        if self.disambiguate:
            name += f" [{self.typename}]"
        if self.map:
            name += f" ({self.map})"
        return name

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

    def is_progression(self) -> bool:
        return self.classification() == ItemClassification.progression

    def is_useful(self) -> bool:
        return self.classification() == ItemClassification.useful

    def is_filler(self) -> bool:
        return not (self.is_progression() or self.is_useful())

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


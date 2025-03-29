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
        if category == "map":
            # Hack hack hack -- this makes it alway compare equal to the synthetic
            # automaps we add to the pool later.
            self.tag = "Automap"
            self.typename = ""

    def __str__(self) -> str:
        return f"DoomItem#{self.id}({self.name()})×{self.count}"

    __repr__ = __str__

    def __eq__(self, other) -> bool:
        return self.tag == other.tag and self.map == other.map

    def update_skill_from(self, other) -> None:
        for sk,count in other.count.items():
            self.count[sk] = self.count.get(sk, 0) + count

    def set_count(self, count: int, skill: frozenset = frozenset({1,2,3})):
        """
        Set the count of the item on the given skill levels to the given value.

        This is currently used to make sure keys exist exactly once on all skills
        if they exist on any of them.
        """
        for sk in skill:
            self.count[sk] = count

    def get_count(self, options, nrof_maps):
        count = self.count.get(options.spawn_filter.value, 0)

        if self.category == "weapon":
            if options.max_weapon_copies.value > 0:
                count = min(count, options.max_weapon_copies.value)
            if options.levels_per_weapon.value > 0:
                count = min(count, max(1, nrof_maps // options.levels_per_weapon.value))

        return count

    def name(self) -> str:
        """Returns the user-facing Archipelago name for this item."""
        name = self.tag
        if self.category == "map":
            name = "Automap"
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

    def is_default_enabled(self) -> bool:
        return self.category in {"map", "weapon", "key", "token", "powerup", "big-health", "big-ammo", "big-armor"}

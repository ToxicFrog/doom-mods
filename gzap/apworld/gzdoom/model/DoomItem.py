"""
Data model for items (or rather, item types) in Doom.
"""

import sys
from typing import Optional, Set, Dict, FrozenSet
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
    id: Optional[int] = None    # AP item ID, assigned by the caller
    categories: FrozenSet[str]  # Randomization categories (e.g. key, weapon, big, small)
    typename: str               # gzDoom class name
    tag: str                    # User-visible name *in gzDoom*
    map: Optional[str] = None
    disambiguate: bool = False
    virtual: bool = True    # Does't exist in-game, only in AP's internal state

    def __init__(self, map, category, typename, tag):
        # 'category' comes from the logic file and is a hyphen-separated string
        self.categories = frozenset(category.split('-'))
        self.typename = typename
        self.tag = tag
        # TODO: We need a better way of handling scoped items, so that things
        # other than these types can be marked as scoped, so that we can have
        # non-scoped tokens, etc
        if self.has_category('key', 'token'):
            self.map = map

    def __str__(self) -> str:
        return f"DoomItem#{self.id}({self.name()})"

    __repr__ = __str__

    def __eq__(self, other) -> bool:
        return self.typename == other.typename and self.map == other.map

    def name(self) -> str:
        """Returns the user-facing Archipelago name for this item."""
        name = self.tag
        if self.disambiguate:
            name += f" [{self.typename}]"
        if self.map:
            name += f" ({self.map})"
        return name

    def has_category(self, *args):
        return self.categories & frozenset(args)

    def classification(self) -> ItemClassification:
        # TODO: now that we can attach multiple categories to items, we should
        # clean this up some and base these decisions entirely on the categories
        # and not on the typename, to let us have a "map token" distinct from
        # "win token" etc.
        if self.typename == "GZAP_Automap" and self.has_category('token'):
            return ItemClassification.useful
        elif self.has_category('key', 'token', 'weapon'):
            return ItemClassification.progression
        elif self.has_category('map', 'upgrade'):
            return ItemClassification.useful
        else:
            return ItemClassification.filler

    def is_progression(self) -> bool:
        return self.classification() == ItemClassification.progression

    def is_useful(self) -> bool:
        return self.classification() == ItemClassification.useful

    def is_filler(self) -> bool:
        return not (self.is_progression() or self.is_useful())

    def pool_limits(self, world):
        """
        Returns the lower and upper bounds for how many copies of this can be in the item pool.

        In some cases this depends on YAML options and which maps are selected.
        """
        # Each key in this WAD must be included exactly once.
        if self.has_category('key'):
            if world.key_in_world(self.name()):
                return (1,1)
            else:
                return (0,0)

        # Allmaps are excluded from the pool. The randomizer will add map tokens
        # to the pool (or not) depending on settings.
        if self.has_category('map'):
            return (0,0)

        # Weapons have an upper bound that depends on settings.
        if self.has_category('weapon'):
            count = sys.maxsize
            if world.options.max_weapon_copies.value > 0:
                count = min(count, world.options.max_weapon_copies.value)
            if world.options.levels_per_weapon.value > 0:
                count = min(count, max(1, len(world.maps) // world.options.levels_per_weapon.value))
            return (0, count)

        # Anything else we just take as many as we find.
        return (0, sys.maxsize)

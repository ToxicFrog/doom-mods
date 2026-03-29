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
    typename: str               # UZDoom class name
    tag: str                    # User-visible name *in UZDoom*
    map: Optional[str] = None
    disambiguate: bool = False

    def __init__(self, map, category, typename, tag):
        # 'category' comes from the logic file and is a hyphen-separated string
        self.categories = frozenset(category.split('-'))
        self.typename = typename
        self.tag = tag
        # TODO: Hack for old logic files that don't explicitly set ap_progression/ap_useful
        if self.has_category('key', 'weapon'):
            self.categories = self.categories | frozenset(['ap_progression'])
        # TODO: We need a better way of handling scoped items, so that things
        # other than these types can be marked as scoped, so that we can have
        # non-scoped flags, etc. Maybe level-scoped weapons someday so that
        # rather than finding "the rocket launcher" you find "the ability to
        # use the rocket launcher in map X".
        if self.has_category('key', 'ap_flag'):
            self.map = map

    def __str__(self) -> str:
        return f"DoomItem#{self.id}({self.name()})"

    __repr__ = __str__

    def __eq__(self, other) -> bool:
        return self.typename == other.typename and self.map == other.map

    def name(self, with_scope: bool = True) -> str:
        """
        Returns the user-facing Archipelago name for this item.

        If with_scope is False, returns a version without the (MAP01) suffix
        used for e.g. keys, suitable for use as part of a location name.
        """
        name = self.tag
        if self.disambiguate:
            name += f" [{self.typename}]"
        if self.map and with_scope:
            name += f" ({self.map})"
        return name

    def typename_for_icon(self):
        return self.typename

    def has_category(self, *args):
        return self.categories & frozenset(args)

    def classification(self) -> ItemClassification:
        classification = ItemClassification.filler
        if self.has_category('ap_trap'):
            classification |= ItemClassification.trap
        if self.has_category('ap_useful'):
            classification |= ItemClassification.useful
        if self.has_category('ap_progression'):
            classification |= ItemClassification.progression
        if self.has_category('ap_skip_balancing'):
            assert ItemClassification.progression in classification, 'ap_skip_balancing is only allowed on progression items'
            classification |= ItemClassification.skip_balancing
        if self.has_category('ap_deprioritized'):
            assert ItemClassification.progression in classification, 'ap_deprioritized is only allowed on progression items'
            classification |= ItemClassification.deprioritized
        return classification

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
                return (1,world.key_in_world(self.name()).count)
            else:
                return (0,0)

        # Allmaps are excluded from the pool. The randomizer will add AP automaps
        # to the pool (or not) depending on settings.
        if self.has_category('maprevealer'):
            return (0,0)

        # Weapons have an upper bound that depends on settings.
        if self.has_category('weapon'):
            count = sys.maxsize
            if world.options.max_weapon_copies.value > 0:
                count = min(count, world.options.max_weapon_copies.value)
            return (0, count)

        # Anything else we just take as many as we find.
        return (0, sys.maxsize)


class DoomFlag(DoomItem):
    """
    A type of DoomItem that is managed entirely by Archipelago and has a name
    wholly controlled by the apworld. Used for tracking or granting of randomizer
    state like "can the player access this level".
    """
    def name(self) -> str:
        return self.tag

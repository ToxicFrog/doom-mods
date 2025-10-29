"""
Data model for the locations items are found at in the WAD.
"""

from typing import NamedTuple, Optional, Set, List, FrozenSet, Collection

from . import DoomItem, prereqs

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
    categories: FrozenSet[str]
    pos: DoomPosition | None = None
    # Minimal sets of keys needed to access this location.
    # Initially None. Tuning data is used to initialize and refine this.
    # At the end of tuning, if still None, is replaced with a pessimal value;
    # this is done at the end of tuning to account for AP-KEYs that are only
    # detected during the tuning process.
    keys: FrozenSet[FrozenSet[str]] | None = None
    # Used to store tuning records while tuning data is being loaded, which are
    # then processed to produce the actual keyset.
    tuning: Set[str]
    # Name of enclosing subregion. If not set, this location is enclosed by the
    # map as a whole.
    region: str | None  = None
    item: DoomItem | None = None  # Used for place_locked_item
    parent = None  # The enclosing DoomWad
    orig_item = None
    disambiguation: str = None
    custom_name: str = None
    skill: Set[int]
    unreachable: bool = False
    secret: bool = False
    sector: int = 0

    def __init__(self, parent, map: str, item: DoomItem, secret: bool, pos: dict | None, custom_name: str | None = None):
        self.parent = parent
        self.categories = frozenset(['secret']) if secret else frozenset()
        self.custom_name = custom_name
        self.tuning = set()
        if item:
            # If created without an item it is the caller's responsibility to fill
            # in these fields post hoc.
            self.categories |= item.categories
            self.orig_item = item
            self.item_name = item.tag
        self.skill = set()
        self.secret = secret
        if pos:
            self.pos = DoomPosition(map=map, virtual=False, **pos)
        else:
            self.pos = DoomPosition(map=map, virtual=True, x=0, y=0, z=0)

    def __str__(self) -> str:
        return f"DoomLocation#{self.id}({self.name()} @ {self.pos} % {self.keys})"

    __repr__ = __str__

    def name(self) -> str:
        name = f"{self.pos.map} - {self.custom_name or self.item_name}"
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

    def has_category(self, *args):
        return self.categories & frozenset(args)

    def is_default_enabled(self) -> bool:
        return self.has_category('weapon', 'key', 'token', 'powerup', 'big', 'sector')

    def record_tuning(self, keys: List[str] | None, region: str | None):
        """
        Record a single tuning record for this location. This won't be turned into
        actual reachability logic until all logic and tuning has been loaded.

        The tuning data is stored as a list of sets of requirement strings.
        Once all tuning data is loaded, it gets minimized (redundant sets pruned)
        and turned into actual evaluatable requirements.

        A complication from the region: we shouldn't model that as an additional
        condition, but rather, insert this location into the named region when
        creating regions and locations.

        So when AP-REGION fires we need to create a region (either an actual
        AP Region or a placeholder we reify later), and we need to associate the
        locations with it, or error out if we can't, or if the same location is
        assigned to multiple regions.
        """
        if region:
            assert (not self.region or self.region == region), f'Location {self.name()} is listed as both in region {self.region} and in region {region}'
            self.region = region

        if keys:
            self.tuning.add(frozenset(k if '/' in k else 'key/'+k for k in keys))

    def finalize_tuning(self):
        """
        Compute the minimal version of the tuning data and store it in self.keys.

        If there is no tuning data, produce a default (pessimistic) tuning
        configuration.
        """
        # If we have tuning data for this location it will have either a tuning
        # set or a region affiliation (or both) and those will provide the logic.
        # If not, we have to autogenerate pessimistic logic for it that assumes
        # we need every key in the level in order to reach it.
        if not self.tuning and not self.region:
            self.keys = frozenset([
                frozenset(
                    'key/'+key.typename
                    for key in self.parent.keys_for_map(self.pos.map))])
            return

        keysets = set()
        for tuning in self.tuning:
            # Remove all keysets we've seen so far that the tuning is a proper
            # subset of
            keysets = set(ks for ks in keysets if not (tuning < ks))
            # Add the new keyset iff there is no existing keyset that it is a
            # proper superset of.
            if not frozenset(ks for ks in keysets if ks < tuning):
                keysets.add(frozenset(tuning))

        self.keys = frozenset(keysets)

    def access_rule(self, world):
        """
        Convert the string-based requirements in self.keys into a callable rule
        evaluator for use by the logic engine.
        """
        ps = [
            prereqs.strings_to_prereq_fn(world, self.parent, self.parent.maps[self.pos.map], ks)
            for ks in self.keys
        ]

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

            # If this location has no prerequisites, trivially succeed.
            if not ps:
                return True

            # Prereqs is an or-of-ands, so if any prereq succeeds, the rule
            # succeeds.
            for prereq in ps:
                if prereq(state):
                    return True

            # If keys are forced to be in vanilla locations, assume that all
            # items are reachable since key-based progression will work as normal.
            # TODO: replace with a more sophisticated check that confirms that
            # *all* items we have as prereqs have vanilla location placement.
            if world.options.included_item_categories.all_keys_are_vanilla:
                return True

            # In classical doom, we can make some simplifying assumptions that
            # do not hold in hublogic mode.
            if 'use_hub_logic' in self.parent.flags:
                return False

            # If the level only has one key, we know it must be reachable
            # without any other keys, even if we can't assume anything about
            # other locations in the same level.
            if self.has_category('key') and self.parent.get_map(self.pos.map).has_one_key(self.orig_item.name()):
                return True

            return False

        return rule

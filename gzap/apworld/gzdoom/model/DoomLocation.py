"""
Data model for the locations items are found at in the WAD.
"""

from typing import NamedTuple, Optional, Set, List, FrozenSet, Collection

from .DoomItem import DoomItem
from .DoomReachable import DoomReachable

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


class DoomLocation(DoomReachable):
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
    region: str | None  = None
    item: DoomItem | None = None  # Used for place_locked_item
    parent = None  # The enclosing DoomWad
    orig_item = None
    disambiguation: str = None
    custom_name: str = None
    skill: Set[int]
    secret: bool = False
    sector: int = 0

    def __init__(self, parent, map: str, item: DoomItem, secret: bool, pos: dict | None, custom_name: str | None = None):
        super().__init__()
        self.parent = parent
        self.categories = frozenset(['secret']) if secret else frozenset()
        self.custom_name = custom_name
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

    def record_tuning(self, keys: List[str] = None, region: str = None, unreachable: bool = None):
        if region:
            assert (not self.region or self.region == region), f'Location {self.name()} is listed as both in region {self.region} and in region {region}'
            self.region = region

        if keys:
            # print(f'Recording tuning record for {self.name()}: {region} {keys}')
            super().record_tuning(keys, unreachable)

    def assume_key_reachable(self):
        '''
        Edge-case untuned logic optimization: if the game isn't using
        hubclusters (so each map is known beatable without involving other
        maps), and we know this location is the only key in the map, we know it
        must be reachable without any other keys.
        '''
        return (
            'use_hub_logic' not in self.parent.flags
            and self.has_category('key')
            and self.parent.get_map(self.pos.map).has_one_key(self.orig_item.name()))

    def finalize_tuning(self):
        # If we have tuning data for this location it will have either a tuning
        # set or a region affiliation (or both) and those will provide the logic.
        # If not, we have to autogenerate pessimistic logic for it that assumes
        # we need every key in the level in order to reach it.
        if self.region:
            # If we have a region defined, our default tuning is empty, since the
            # enclosing region will provide reachability constraints.
            super().finalize_tuning(default=[])
        elif self.assume_key_reachable():
            super().finalize_tuning(default=[frozenset()])
        else:
            super().finalize_tuning(default=[
                frozenset(
                    'key/'+key.typename
                    for key in self.parent.keys_for_map(self.pos.map))
            ])

    def access_rule(self, world):
        return super().access_rule(world, self.parent, self.parent.get_map(self.pos.map))

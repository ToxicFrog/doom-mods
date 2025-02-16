"""
Data model for a single map.

A map is *mostly* just a list of locations, but it also needs to know what the IDs
are for the items that grant map-specific items (access codes, the automap, etc);
for the purpose of reachability information, it also needs to know what keys and
weapons it contains.
"""
from dataclasses import dataclass, field, InitVar
from typing import Dict, List, NamedTuple, Optional, Set

from . import DoomItem, DoomLocation


class MAPINFO(NamedTuple):
    """
    Information about a map used to generate the MAPINFO lump.

    This is a subset of what MAPINFO actually supports and it is likely this will
    need to be expanded -- this is just what's needed to support Doom 2.
    """
    levelnum: int
    cluster: int
    title: str
    is_lookup: bool
    music: str
    music_track: int
    sky1: str
    sky1speed: float
    sky2: str
    sky2speed: float
    flags: List[str]


@dataclass
class DoomMap:
    """
    Information about a level (or, equivalently, a map) in the WAD.

    This includes not just its locations, but information needed to construct a
    valid MAPINFO entry, IDs for synthetic items like the access and clear flags,
    and balancing information.

    At generation time, each DoomMap produces exactly one AP Region, which contains
    all of its locations. We don't attempt to subdivide maps further. The "do you
    have access at all" and "do you have enough gun" reachability checks live on
    the Region, while "do you have enough keys" lives on the Locations.
    """
    map: str
    # JSON initializer for the mapinfo
    info: InitVar[Dict]
    # Data for the MAPINFO lump
    mapinfo: Optional[MAPINFO] = None
    # Key and weapon information for computing access rules
    keyset: Set[str] = field(default_factory=set)
    gunset: Set[str] = field(default_factory=set)
    # All locations contained in this map
    locations: List[DoomLocation] = field(default_factory=list)

    def __post_init__(self, info):
        self.mapinfo = MAPINFO(**info)

    def access_rule(self, player, require_weapons = True):
        def rule(state):
            if not state.has(self.access_token_name(), player):
                return False

            if not require_weapons:
                return True

            # We need at least half of the non-secret guns in the level,
            # rounded down, to give the player a fighting chance.
            player_guns = { gun for gun in self.gunset if state.has(gun, player) }
            if len(player_guns) < len(self.gunset)//2:
                return False

            return True

        return rule

    def access_token_name(self):
        return f"Level Access ({self.map})"

    def automap_name(self):
        return f"Automap ({self.map})"

    def clear_token_name(self):
        return f"Level Clear ({self.map})"

    def exit_location_name(self):
        return f"{self.map} - Exit"

    def starting_items(self):
        """Return all items needed if this is a starting level for the player."""
        return self.keyset | {self.access_token_name()}

    def register_location(self, loc: DoomLocation) -> None:
        if loc not in self.locations:
            self.locations.append(loc)

    def update_access_tracking(self, item: DoomItem) -> None:
        """Update the keyset or gunset based on the knowledge that this item exists in the level."""
        if item.category == "key":
            self.keyset.add(item.name())
        if item.category == "weapon":
            self.gunset.add(item.name())

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
    # Item IDs for the various tokens that unlock or mark the level as finished
    access_id: int
    automap_id: int
    clear_id: int
    exit_id: int
    # JSON initializer for the mapinfo
    info: InitVar[Dict]
    # Data for the MAPINFO lump
    mapinfo: Optional[MAPINFO] = None
    # Key and weapon information for computing access rules
    keyset: Set[DoomItem] = field(default_factory=set)
    gunset: Set[DoomItem] = field(default_factory=set)
    # All locations contained in this map
    locations: List[DoomLocation] = field(default_factory=list)

    def __post_init__(self, info):
        self.mapinfo = MAPINFO(**info)

    def access_rule(self, player):
        def rule(state):
            if not state.has(self.access_token_name(), player):
                return False

            # We need at least half of the non-secret guns in the level,
            # rounded down, to give the player a fighting chance.
            player_guns = { item.name for item in self.gunset if state.has(item.name, player) }
            if len(player_guns) < len(self.gunset)//2:
                return False

            return True

        return rule

    def access_token_name(self):
        return f"Level Access ({self.map})"

    def clear_token_name(self):
        return f"Level Clear ({self.map})"

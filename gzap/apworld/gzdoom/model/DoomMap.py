"""
Data model for a single map.

A map is *mostly* just a list of locations, but it also needs to know what the IDs
are for the items that grant map-specific items (access codes, the automap, etc);
for the purpose of reachability information, it also needs to know what keys and
weapons it contains.
"""
from dataclasses import dataclass, field, InitVar
from math import ceil
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
    checksum: str
    # JSON initializer for the mapinfo
    info: InitVar[Dict]
    monster_count: int = 0
    # Data for the MAPINFO lump
    rank: int = 0
    mapinfo: Optional[MAPINFO] = None
    # Key and weapon information for computing access rules
    # Keys in the level
    keyset: Set[str] = field(default_factory=set)
    # Non-secret guns in the level
    local_gunset: Set[str] = field(default_factory=set)
    # Non-secret guns in levels preceding this one
    carryover_gunset: Set[str] = field(default_factory=set)
    # All locations contained in this map
    locations: List[DoomLocation] = field(default_factory=list)
    # Items not contained in any particular location that should nonetheless
    # be added to the pool if this map is included in play.
    loose_items: Dict[str,int] = field(default_factory=dict)
    # "Clear Token" names for all maps preceding this one in the scanned level
    # order
    prior_clears: Set[str] = field(default_factory=set)

    def __post_init__(self, info):
        self.mapinfo = MAPINFO(**info)

    def all_locations(self, skill: int, categories: Set[str]) -> List[DoomLocation]:
        skill = min(3, max(1, skill)) # clamp ITYTD->HNTR and N!->UV
        return [
            loc for loc in self.locations
            if skill in loc.skill and (not categories or loc.category in categories)
        ]

    def choose_locations(self, world):
        skill = world.spawn_filter
        chosen = []
        for category,amount in world.included_item_categories.items():
            if amount == 0:
                continue

            if hasattr(world.multiworld, "generation_is_fake"):
                # Universal Tracker support. If UT is generating, include all
                # locations that could potentially be in the pool, whether they
                # were or not.
                amount = 1.0

            buf = self.all_locations(skill, {category})
            count = ceil(len(buf) * amount)
            chosen.extend(world.random.sample(buf,count))
        return chosen

    def access_rule(self, world):
        # print(f"access_rule({self.map}) = start={world.is_starting_map(self.map)}, co-guns({world.options.carryover_weapon_bias.value})={self.carryover_gunset}, local-guns({world.options.local_weapon_bias.value})={self.local_gunset}, clears({world.options.level_order_bias.value})={self.prior_clears}")
        def rule(state):
            if world.options.pretuning_mode:
                return True

            if not state.has(self.access_token_name(), world.player):
                return False

            # Starting levels are exempt from all balancing checks.
            if world.is_starting_map(self.map):
                return True

            # If Universal Tracker is asking for "glitch logic", skip all balancing
            # checks and report everything the player can get to whether they have
            # the firepower to keep it or not.
            if state.has(world.glitches_item_name, world.player):
                return True

            # Check requirement for guns the player would normally carryover
            # from earlier levels.
            player_guns = { gun for gun in self.carryover_gunset if state.has(gun, world.player) }
            guns_needed = (world.options.carryover_weapon_bias.value / 100) * len(self.carryover_gunset)
            if len(player_guns) < round(guns_needed):
                return False

            # Check requirement for guns the player would normally find in this
            # level when pistol-starting.
            player_guns = { gun for gun in self.local_gunset if state.has(gun, world.player) }
            guns_needed = (world.options.local_weapon_bias.value / 100) * len(self.local_gunset)
            if len(player_guns) < round(guns_needed):
                return False

            # We also need to have cleared some number of preceding levels based
            # on the level_order_bias
            levels_cleared = {
                token for token in self.prior_clears
                if state.has(token, world.player)
            }
            levels_needed = (world.options.level_order_bias.value / 100) * len(self.prior_clears)
            if len(levels_cleared) < round(levels_needed):
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

    def add_loose_item(self, item, count=1):
        self.loose_items[item] = self.loose_items.get(item, 0) + count

    def starting_items(self, options):
        """Return all items needed if this is a starting level for the player."""
        if options.start_with_keys:
            return self.keyset | {self.access_token_name()}
        else:
            return {self.access_token_name()}

    def register_location(self, loc: DoomLocation) -> None:
        if loc not in self.locations:
            self.locations.append(loc)

    def update_access_tracking(self, item: DoomItem) -> None:
        """Update the keyset based on the knowledge that this item exists in the level."""
        if item.category == "key":
            self.keyset.add(item.name())

    def build_priors(self, prior_maps: List['DoomMap']) -> None:
        self.prior_clears = { map.clear_token_name() for map in prior_maps }
        self.local_gunset = {
            loc.orig_item.name()
            for loc in self.locations
            if not loc.secret and not loc.unreachable and loc.category == "weapon"
        }
        self.carryover_gunset = set()
        for map in prior_maps:
            self.carryover_gunset |= map.local_gunset

        # print(self.map, [map.map for map in prior_maps], self.carryover_gunset, self.local_gunset)

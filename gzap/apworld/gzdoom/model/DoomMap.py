"""
Data model for a single map.

A map is *mostly* just a list of locations, but it also needs to know what the IDs
are for the items that grant map-specific items (access codes, the automap, etc);
for the purpose of reachability information, it also needs to know what keys and
weapons it contains.
"""
from dataclasses import dataclass, field, InitVar
from math import ceil
from typing import Dict, List, NamedTuple, Optional, Set, Type

from .DoomLocation import DoomLocation
from .DoomKey import DoomKey
from .DoomReachable import DoomReachable


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
    wad: Type['DoomWad']
    # JSON initializer for the mapinfo
    info: InitVar[Dict]
    monster_count: int = 0
    # Data for the MAPINFO lump
    rank: int = 0
    mapinfo: Optional[MAPINFO] = None
    clustername: str = ''
    # Key and weapon information for computing access rules
    # Keys in the level
    keyset: Set[DoomKey] = field(default_factory=set)
    # Number of keys (not number of distinct keys -- a level with two RedCards
    # will have '2' here). For levels where |keyset|==1, used to check if we can
    # safely assume that key is accessible from the start.
    key_count: int = 0
    # All locations contained in this map
    locations: List[DoomLocation] = field(default_factory=list)
    # Items not contained in any particular location that should nonetheless
    # be added to the pool if this map is included in play.
    loose_items: Dict[str,int] = field(default_factory=dict)
    extra_rules: DoomReachable = field(default_factory=DoomReachable)

    def __post_init__(self, info):
        self.mapinfo = MAPINFO(**info)

    def all_locations(self, skill: int, categories: Set[str]) -> List[DoomLocation]:
        skill = min(3, max(1, skill)) # clamp ITYTD->HNTR and N!->UV
        return [
            loc for loc in self.locations
            if skill in loc.skill and (not categories or loc.has_category(*categories))
        ]

    def access_rule(self, world):
        # print(f"access_rule({self.map}) = start={world.is_starting_map(self.map)}, co-guns({world.options.carryover_weapon_bias.value})={self.carryover_gunset}, local-guns({world.options.local_weapon_bias.value})={self.local_gunset}, clears({world.options.level_order_bias.value})={self.prior_clears}")
        prior_maps = [ map for map in world.maps if map.rank < self.rank ]
        local_guns = self.local_guns()
        carryover_guns = set()
        for map in prior_maps:
            carryover_guns |= map.local_guns()

        if self.extra_rules.prereqs:
            extra_rule = self.extra_rules.access_rule(world, self.wad, self)
        else:
            extra_rule = lambda _: True

        def rule(state):
            if world.options.pretuning_mode:
                return True

            if not state.has(self.access_token_name(), world.player):
                return False

            if not extra_rule(state):
                return False

            # Starting levels are exempt from all balancing checks.
            if world.is_starting_map(self.map):
                return True

            # If Universal Tracker is asking for "glitch logic", skip all balancing
            # checks and report everything the player can get to whether they have
            # the firepower to keep it or not.
            if state.has(world.glitches_item_name, world.player):
                return True

            # If hublogic is on, skip per-map weapon logic.
            if self.wad.use_hub_logic():
                return True

            # Check requirement for guns the player would normally carryover
            # from earlier levels.
            player_guns = { gun for gun in carryover_guns if state.has(gun, world.player) }
            guns_needed = (world.options.carryover_weapon_bias.value / 100) * len(carryover_guns)
            if len(player_guns) < round(guns_needed):
                return False

            # Check requirement for guns the player would normally find in this
            # level when pistol-starting.
            player_guns = { gun for gun in local_guns if state.has(gun, world.player) }
            guns_needed = (world.options.local_weapon_bias.value / 100) * len(local_guns)
            if len(player_guns) < round(guns_needed):
                return False

            # We also need to have cleared some number of preceding levels based
            # on the level_order_bias
            levels_cleared = {
                map.clear_token_name() for map in prior_maps
                if state.has(map.clear_token_name(), world.player)
            }
            levels_needed = (world.options.level_order_bias.value / 100) * len(prior_maps)
            if len(levels_cleared) < round(levels_needed):
                return False

            return True

        return rule

    def access_token_name(self):
        return f"Level Access ({self.map})"

    def automap_name(self):
        return f"Automap ({self.map})"

    def clear_token_name(self):
        if self.clustername:
            return f'Chapter Clear ({self.clustername})'
        else:
            return f'Level Clear ({self.map})'

    def exit_location_name(self):
        if self.wad.use_hub_logic() and not self.map in self.wad.hub_logic_exits():
            # In hub mode, only maps containing cluster exits get exit locations.
            return None
        return f'{self.map} - Exit'

    def add_loose_item(self, item, count=1):
        self.loose_items[item] = self.loose_items.get(item, 0) + count

    def starting_items(self, options):
        """Return all items needed if this is a starting level for the player."""
        if options.start_with_keys:
            return {key.fqin() for key in self.keyset} | {self.access_token_name()}
        else:
            return {self.access_token_name()}

    def register_location(self, loc: DoomLocation) -> None:
        if loc in self.locations:
            return

        self.locations.append(loc)
        if loc.has_category('key'):
            self.key_count += 1

    def has_one_key(self, keyname: str) -> bool:
        return self.key_count == 1 and keyname in {k.fqin() for k in self.keyset}

    def key_by_type(self, typename: str) -> DoomKey:
        for key in self.keyset:
            if key.typename == typename:
                return key
        raise RuntimeError(f"Couldn't find key of type {typename} in map {self.name} with keys {self.keyset}")

    def local_guns(self):
        return {
            loc.orig_item.name()
            for loc in self.locations
            if not loc.secret and not loc.unreachable and loc.has_category('weapon')
        }

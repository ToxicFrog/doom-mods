"""
Data model for a single map.

A map is *mostly* just a list of locations, but it also needs to know what the IDs
are for the items that grant map-specific items (access codes, the automap, etc);
for the purpose of reachability information, it also needs to know what keys and
weapons it contains.
"""
from collections import Counter
from dataclasses import dataclass, field, InitVar
from math import ceil
from typing import Dict, List, NamedTuple, Optional, Set, Type

from rule_builder.rules import Or, False_, True_, And, Has

from .DoomLocation import DoomLocation
from .DoomKey import DoomKey
from .DoomReachable import DoomReachable
from .prereqs import weapon_prereq, strings_to_rule, weapon_from_hint, is_combat_logic_hint

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
    # User-readable titles, if available, from LevelLocals
    # clustername may also be provided by GZAPRC
    levelname: str | None = None
    episodename: str | None = None
    clustername: str | None = None
    # Total monster count
    monster_count: int = 0
    # Monster count by typename
    monsters: Dict[str,int] = field(default_factory=dict)
    # Extra prereqs defined in GZAPRC that apply to the whole map
    prereqs: List[str] = field(default_factory=list)
    # Data for the MAPINFO lump
    rank: int = 0
    mapinfo: Optional[MAPINFO] = None
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
        self.extra_rules.debug_name = f'map/{self.map}'

    def finalize_tuning(self):
        self.extra_rules.finalize_tuning(default=[])
        self.extra_rules.add_universal_prereqs(self.prereqs)

    def all_locations(self, spawn_filter: int, categories: Set[str]) -> List[DoomLocation]:
        return [
            loc for loc in self.locations
            if spawn_filter & loc.spawn_filter and (not categories or loc.has_category(*categories))
        ]

    def default_enabled_location_count(self, spawn_filter: int = 0x08):
        return len([
            loc for loc in self.locations
            if spawn_filter & loc.spawn_filter and loc.is_default_enabled()
        ])

    def access_rule(self, world):
        if world.options.pretuning_mode:
            return True_()

        rules = [Has(self.access_flag_name())]

        if self.extra_rules.prereqs:
            rules.append(self.extra_rules.access_rule(world, self.wad, self))

        return And(*rules)

    def access_flag_name(self):
        if self.levelname:
            return f"{self.map}: {self.levelname}"
        elif self.mapinfo.title and not self.mapinfo.is_lookup:
            return f"{self.map}: {self.mapinfo.title}"
        else:
            return f"Level Access ({self.map})"

    def automap_name(self):
        return f"Automap ({self.map})"

    def clear_flag_name(self):
        if self.clustername and self.wad.use_hub_logic():
            return f'Chapter Clear ({self.clustername})'
        else:
            return f'Level Clear ({self.map})'

    def add_loose_item(self, item, count=1):
        self.loose_items[item] = self.loose_items.get(item, 0) + count

    def starting_items(self, options):
        """Return all items needed if this is a starting level for the player."""
        if options.start_with_keys:
            return {key.fqin() for key in self.keyset} | {self.access_flag_name()}
        else:
            return {self.access_flag_name()}

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
        raise RuntimeError(f"Couldn't find key of type {typename} in map {self.map} with keys {self.keyset}")

    def should_include_weapon(self, world, loc) -> bool:
        return (
            loc.has_category('weapon') and not loc.unreachable
            and (not loc.has_category('secret') or world.options.combat_logic_secrets))

    def local_weapons(self, world) -> Counter[str]:
        # FIXME: enemy drops are not counted in this. So if the GZAPRC says that
        # levels with shotgunners should logically require the shotgun, we infer
        # that requirement for the level, but don't treat the level as being one
        # that you can find the shotgun in.
        # We should probably promote /auto weapon requirements from the tuning
        # file to inferred weapon pickups here.
        return Counter(
            loc.orig_item.typename
            for loc in self.locations
            if self.should_include_weapon(world, loc)
        ) + Counter(
            weapon_from_hint(prereq)
            for prereq in self.prereqs
            if is_combat_logic_hint(prereq)
        )

    def prior_weapons(self, world) -> Counter[str]:
        weapons = Counter()
        for map in self.prior_maps(world):
            # print(f'prior_weapons({self.map}): {map.map} contains {map.local_weapons(world)}')
            weapons += map.local_weapons(world)
        return weapons

    def combat_logic_weapons(self, world):
        if world.options.combat_logic_mode == 'auto_per_episode':
            return frozenset(
                weapon
                for weapon in (self.local_weapons(world) + self.prior_weapons(world)).keys()
            )
        elif world.options.combat_logic_mode == 'auto_per_level':
            return frozenset(weapon for weapon in self.local_weapons(world))
        else:
            return frozenset()

    def is_same_episode(self, other) -> bool:
        # This is a bit of a hack: assume that something is in the same episode
        # if its map lumpname starts with the same two characters.
        # This will work for Doom 1 and Heretic style wads, and it works
        # trivially for Doom 2 wads that don't divide things into episodes
        # It will not work for e.g. Space Cats Saga or Hedon Bloodrite that
        # use Doom 2 map naming conventions but have distinct episodes that
        # are each meant to be played separately.
        # We also look at the episodename field, but this isn't set for any
        # current logic files and probably won't be reliably populated until
        # the next uzdoom release adds EpisodeData to the API.
        if self.episodename:
            return self.episodename == other.episodename
        else:
            return other.map.startswith(self.map[0:2])

    def prior_maps(self, world):
        return sorted([
            map for map in world.maps
            if map.rank < self.rank and self.is_same_episode(map)
        ], key=lambda m: m.rank)

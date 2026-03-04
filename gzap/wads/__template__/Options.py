# TODO: add/implement options for:
# - win logic: all levels/N levels/all bosses/N bosses
# - are bosses checks
# - are exits checks (in addition to giving you a clear flag)
#   we do this by making the "level exit flag" an internal event at generation
#   time, and at runtime just setting a flag on the Region object when the level
#   is clear.
# - progressive automap -- automaps bind to the first unmapped level you have,
#   and/or you need multiple automaps to display everything for a level (say,
#   one gets you checks, one gets you geometry, one gets you progression hilights)

from dataclasses import dataclass
from math import ceil,floor
import sys

from Options import PerGameCommonOptions, Toggle, DeathLink, StartInventory, StartInventoryPool, OptionSet, NamedRange, Range, OptionDict, OptionList, OptionError, OptionGroup, Visibility
from worlds.AutoWorld import WebWorld

uzdoom = sys.modules['worlds.uzdoom']
model = sys.modules['worlds.uzdoom.model']
included_logic = model.init_wads(__package__)
wad = included_logic.wad

class MaxWeaponCopies(Range):
    """
    Applies a limit to the number of copies of each weapon in the item pool.

    Lower values mean you may have to wait longer before finding a given weapon,
    but also means more checks will contain health, powerups, etc. rather than
    duplicates of weapons you already have. A setting of 0 removes this limit
    entirely.

    This is an upper bound; it will not add more weapons to the pool than exist
    in the WAD already. By default it is set to 1 per 8 levels.
    """
    display_name = "Max weapon copies"
    range_start = 0
    range_end = len(wad.maps)
    default = ceil(len(wad.maps)/8)

class StartingLevels(OptionSet):
    __doc__ = """
    Levels you can access at the start of the game. You will spawn with access
    codes for these levels; if start_with_keys is enabled, you will also spawn
    with all keys for them. The default setting tries to include enough levels
    to generate reliably even in singleplayer with fairly restrictive settings.

    If you are playing a multiworld game and want to start with nothing at all
    (i.e. Doom is not playable until another world unlocks it), set this to [].

    This option supports globbing expressions.""" + (
    f"""

    For solo play, to avoid generation failures due to a small sphere 1 in
    this wad, you may need to either change included_item_categories to enable
    more item categories, or add more maps here. If doing the latter, the
    apworld's best guess at what to set this to is:
    {wad.default_solo_starting_maps()}
    """
    if wad.default_solo_starting_maps() else ""
    )
    display_name = "Starting levels"
    default = sorted(map.map for map in wad.default_starting_maps())


if wad.get_flag('use_hub_logic'):
    class StartWithKeys(Toggle):
        """Forced off because this WAD uses hub logic."""
        default = False
        visibility = Visibility.none
elif model.tuning_files(wad.package, wad.name):
    class StartWithKeys(Toggle):
        """
        If enabled, you will start with all the keys for your starting_levels.
        """
        default = False
else:
    class StartWithKeys(Toggle):
        """
        If enabled, you will start with all the keys for your starting_levels.

        This WAD lacks tuning data, so setting this to false may cause
        generation failures, especially in singleplayer.
        """
        default = True

class IncludedLevels(OptionSet):
    """
    Levels to randomize. By default this is all levels in the wad.
    """
    display_name = "Included levels"
    default = sorted(wad.maps.keys())

class SpawnFilter(NamedRange):
    """
    Tell the generator which spawn filter (information about what items and enemies
    spawn in each map) the game will use.

    You need to pick a setting here that matches the difficulty you will be playing
    on. In stock Doom, ITYTD and HNTR use "easy" spawns, HMP uses "medium", and
    UV and NM use "hard".

    If you are playing with a mod that changes this, make sure that you choose the
    filter appropriate to the difficulty level you are selecting. Many gameplay mods
    have custom difficulty settings, and it's not always obvious which ones correspond
    to easy/medium/hard.
    """
    display_name = "Spawn filter"
    range_start = 1
    range_end = 3
    default = 2
    special_range_names = {
        "easy": 1,
        "medium": 2,
        "hard": 3
    }

class IncludedItemCategories(OptionList):
    """
    Which item categories to include in randomization. This controls both which
    items are replaced with checks, and what the item pool contains.

    Each entry has the format 'categories:percent'. You can use 'all' or 'none'
    as aliases for '100' or '0'. See doc/glossary.md for an explanation of
    what item categories are available. Categories can be combined using '-',
    e.g. 'secret-health' means all health items that are in secrets.

    For each location or item, entries are checked *in order* and the first entry
    that matches is used. A category of '*' matches everything. Items or locations
    that don't match any entry are excluded by default.

    Using an item name, e.g. 'ArmorBonus:none', is also permitted, and will match
    that exact item. To avoid ambiguity, you have to use Doom's internal name,
    e.g. 'ClipBox' instead of 'Bullets' and 'ArtiHealth' instead of 'Quartz Flask'.

    The default settings:
    - exclude all items in secrets and the secrets themselves, as they can be
      quite difficult to get for inexperienced players depending on the WAD;
    - include all useful and progression items;
    - exclude all small and medium items and all Heretic tools (that are neither
      useful nor progression);
    - and include everything else by default.

    Turning on medium, small, or tool items can increase the number of checks by
    10x or more, so be prepared for a grass-rando-like experience if you do that.

    You can also use two special values in place of a percentage:

      'vanilla'
      All items in this category will be 'randomized' into their vanilla locations.
      Use this instead of 'none' if you want to play with non-randomized keys or
      weapons.

      'shuffle'
      Items in this category will be randomly shuffled with each other locally.
      They will not count towards hint cost calculations.

      'start'
      All items in this category will be placed in your starting inventory instead
      of in the item pool. Use 'key:start', 'weapon:start', or 'ap_map:start' to
      start with all keys, weapons, or maps, respectively.
    """
    display_name = "Included item/location categories"
    default = [
        'secret-sector:none', 'secret-marker:none', 'secret:none',
        'ap_progression:all', 'ap_useful:all', 'big:all',
        'medium:none', 'small:none', 'tool:none',
        '*:all',
    ]

    def verify(self, world, player_name, plando_options):
        super(OptionList, self).verify(world, player_name, plando_options)
        self.build_ratios()

    def build_ratios(self):
        self.ratios = {}
        self.bucket_list = []
        for config in self.actual_value():
            key,ratio = config.split(':')
            assert key != '' and ratio != '', 'Entries in included_item_categories must have both a category and a percentage'
            if key in self.ratios:
                raise OptionError(f'Duplicate entry {key} in included_item_categories')
            self.ratios[key] = self.ratio_value(ratio)
            self.bucket_list.append((frozenset(key.split('-')), key))

        for key in ['ap_map']:
            ratio = self.find_ratio(None, {key})
            if ratio not in {1.0, 'start'}:
                raise OptionError(f'Category {key} has invalid setting {ratio}; this category only permits "all" or "start".')
        for key in ['key', 'weapon']:
            ratio = self.find_ratio(None, {key})
            if ratio not in {1.0, 'vanilla', 'start'}:
                raise OptionError(f'Category {key} has invalid setting {ratio}; this category only permits "all", "vanilla", or "start".')

        # Convenience field used later by the location access logic.
        self.all_keys_are_vanilla = self.find_ratio(None, {'key'}) == 'vanilla'

    def actual_value(self):
        # Player is not allowed to override these parts. Level accesses must
        # always be in the pool -- starting_levels will handle removing them
        # if needed -- and we need a fallback for other flags if the user
        # doesn't specify one.
        return ['ap_level:all'] + self.value + ['ap_flag:all']

    def ratio_value(self, string):
        if string == 'all':
            return 1.0
        elif string == 'none':
            return 0.0
        elif string in {'vanilla', 'start', 'shuffle'}:
            return string
        else:
            return int(string)/100.0

    def ratio_for_bucket(self, bucket):
        if not bucket:
            return 0.0
        return self.ratios[bucket]

    def find_bucket(self, item_type, loc_cats):
        for (categories,bucket) in self.bucket_list:
            if bucket == '*' or categories == {item_type} or categories <= loc_cats:
                return bucket
        return None

    def find_ratio(self, item_type, loc_cats):
        return self.ratio_for_bucket(self.find_bucket(item_type, loc_cats))

    def ratio_for_item(self, item):
        return self.find_ratio(item.typename, item.categories)

    def bucket_for_location(self, loc):
        if loc.orig_item:
            return self.find_bucket(loc.orig_item.typename, loc.categories)
        else:
            return self.find_bucket(None, loc.categories)

class LevelOrderBias(Range):
    """
    How closely the randomizer tries to follow the original level order of the
    WAD. Internally, this is the % of earlier levels you need to be able to beat
    before it will consider later levels in logic. This is primarily useful for
    enforcing at least a bit of difficulty progression rather than being dumped
    straight from MAP01 to MAP30.

    The default setting of 25% means it won't require you to go to (e.g.) MAP08
    until after beating two of the preceding levels.

    Starting levels are exempt from this check.
    """
    display_name = "Level order bias"
    range_start = 0
    range_end = 100
    default = 25 if not wad.use_hub_logic() else 0
    visibility = Visibility.all if not wad.use_hub_logic() else Visibility.none

class LocalWeaponBias(Range):
    """
    How much the randomizer cares about making sure you have access to the
    weapons in a level before it considers that level to be in logic. Most Doom
    levels are possible to beat from a pistol start by finding weapons in the
    level itself, but in the randomizer there is no guarantee the level contains
    any weapons at all; this setting makes the randomizer ensure that some of
    the weapons you would normally find in the level are accessible before you
    enter it.

    The setting is a percentage; higher values mean the randomizer will try to
    make more of the weapons accessible before you need to enter the level. At
    100% it will not consider a level to be in logic until all of the weapons
    normally found in it are accessible to you elsewhere.

    Starting levels are exempt from this check.
    """
    display_name = "In-level weapon bias"
    range_start = 0
    range_end = 100
    default = 0

class GlobalWeaponBias(Range):
    """
    How much the randomizer cares about making sure you have access to the weapons
    you'd start a level with when not pistol-starting (i.e. weapons you'd carry
    over from earlier levels). This setting is somewhat conservative in that it
    doesn't take into account death exits.

    The setting is a percentage; higher values mean the randomizer will try to
    make more of the weapons accessible before you need to enter the level. At
    100% it will not consider a level to be in logic until all of the weapons
    normally found before entering it are availalble to you elsewhere.

    Starting levels are exempt from this check.
    """
    display_name = "Carryover weapon bias"
    range_start = 0
    range_end = 100
    default = 50

class WinMapCount(Range):
    """
    How many maps you need to clear to win the game. By default this is all maps
    in the wad.
    """
    display_name = "Number of maps to win"
    range_start = 0
    range_end = len(wad.all_winnable_map_names())
    default = len(wad.all_winnable_map_names())

class WinMapNames(OptionSet):
    """
    Which specific maps you need to clear to win the game (assuming you have
    changed win_map_count so as not to require all maps). The default is
    Archipelago's best guess at which maps are end-of-episode or end-of-game
    levels.
    """
    display_name = "Specific maps to win"
    default = sorted([map for map in wad.all_boss_map_names()])
    valid_keys = sorted([map for map in wad.all_winnable_map_names()])

class AllowRespawn(Toggle):
    """
    If enabled, the player will respawn at the start of the level on death. If
    disabled they must restore from an earlier save.

    NOTE: restoring from a save will restore the state of the world, but NOT the
    state of the randomizer -- checks already collected will remain collected and
    items used from the randomizer inventory will remain used.
    """
    display_name = "Allow Respawn"
    default = True

class FullPersistence(Toggle):
    """
    If enabled, all levels will be fully persistent, in the same manner as Hexen
    hubclusters. Levels can be reset from the level select menu, but this is all
    or nothing: there is no way to reset individual levels. This is generally
    reliable, but a minority of wads or gameplay mods may break with it.
    """
    display_name = "Persistent Levels"
    default = True

class PreTuningMode(Toggle):
    """
    This setting is for logic developers. If enabled, most other options are
    overridden; only selected_wad and spawn_filter remain functional. All checks
    contain their original items (i.e. there is no randomization) and you start
    with access to all levels, all automaps, and no keys.

    The intent of this mode is to let you play through the game, or specific
    levels, "normally", to generate a tuning file, even in cases where the
    initial scan is so conservative as to cause generation failures.

    Pretuning mode also disables persistent mode and disables automatic MAPINFO
    generation, so the game will retain its original episode divisions,
    intermission text, etc.
    """
    display_name = "Pretuning Mode"
    default = False

class UZDoomStartInventory(StartInventory):
    """
    Start with the specified amount of these items. You can list any valid
    inventory item from the WAD you are playing, even if the randomizer doesn't
    know about it, e.g. "BFG9000: 1" will work even if the WAD contains no BFGs.
    """
    local_actors: dict = None

    def verify(self, world, player_name, plando_options):
        self.local_actors = {
            typename: count
            for typename, count in self.value.items()
            if typename not in world.item_names
        }
        self.value = {
            typename: count
            for typename, count in self.value.items()
            if typename in world.item_names
        }
        super(StartInventory, self).verify(world, player_name, plando_options)


@dataclass
class UZDoomOptions(PerGameCommonOptions):
    # Skill level, WAD, and level selection
    spawn_filter: SpawnFilter
    starting_levels: StartingLevels
    start_with_keys: StartWithKeys
    included_levels: IncludedLevels
    # Win conditions
    win_map_count: WinMapCount
    win_map_names: WinMapNames
    # Combat logic
    level_order_bias: LevelOrderBias
    local_weapon_bias: LocalWeaponBias
    carryover_weapon_bias: GlobalWeaponBias
    # Other settings
    allow_respawn: AllowRespawn
    full_persistence: FullPersistence
    pretuning_mode: PreTuningMode
    # Location/item pool control
    max_weapon_copies: MaxWeaponCopies
    included_item_categories: IncludedItemCategories
    # Stock settings
    start_inventory: UZDoomStartInventory
    start_inventory_from_pool: StartInventoryPool

class UZDoomWeb(WebWorld):
  game = f"UZDoom ({wad.name})"
  option_groups = [
    OptionGroup("Starting Conditions", [
        SpawnFilter, StartingLevels, StartWithKeys, IncludedLevels, UZDoomStartInventory,
    ]),
    OptionGroup("Win Conditions", [
        WinMapCount, WinMapNames,
    ]),
    OptionGroup("Combat Logic", [
        LevelOrderBias, LocalWeaponBias, GlobalWeaponBias,
    ]),
    OptionGroup("Gameplay Settings", [
        AllowRespawn, FullPersistence,
    ]),
    OptionGroup("Randomization Settings", [
        PreTuningMode, MaxWeaponCopies, IncludedItemCategories,
    ]),
  ]

# Apply custom option adjustments, if the wad has a custom.py
# Use this by defining a custom_options function in custom.py that takes the
# UZDoomOptions type as the first argument and any options it wants to modify
# as trailing keyword arguments; it can then modify the class fields as it sees
# fit. See wads/the_adventures_of_square/custom.py for a simple example.
try:
    from .custom import custom_options
    custom_options(UZDoomOptions, **{
        name: field.type for name, field in UZDoomOptions.__dataclass_fields__.items()
    })
except ModuleNotFoundError:
    # It's ok if there's no custom.py. Any other problem loading it is an error.
    pass

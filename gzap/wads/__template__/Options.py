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

from Options import PerGameCommonOptions, Toggle, DeathLink, StartInventory, StartInventoryPool, OptionSet, NamedRange, Range, OptionDict, OptionList, OptionError, OptionGroup, Visibility, TextChoice, Choice
from worlds.AutoWorld import WebWorld

uzdoom = sys.modules['worlds.uzdoom']
model = sys.modules['worlds.uzdoom.model']
included_logic = model.init_wads(__package__)
wad = included_logic.wad


###############################################################################
# Initial conditions
###############################################################################

class SpawnFilter(NamedRange):
    """
    Tell the generator which spawn filter (information about what items and enemies
    spawn in each map) the game will use.

    You need to pick a setting here that matches the difficulty you will be playing
    on. In unmodified games filters 1 through 5 correspond to the five difficulty
    levels, ITYTD through Nightmare -- although in most WADs 1/2 and 4/5 use the
    same spawns.

    Some mods implement custom difficulty levels that use different spawn filters
    than the original game, so make sure you choose a filter that matches the
    difficulty you are actually playing. If you get it wrong, you will get a
    warning on entering the game.
    """
    display_name = "Spawn filter"
    range_start = 1
    range_end = 8
    default = 3
    special_range_names = {
        "itytd": 1,
        "hntr": 2,
        "hmp": 3,
        "uv": 4,
        "nm": 5,
    }

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

    This wad has a small sphere 1 with default settings.. To avoid generation
    failures in solo play, you may need to do one or more of:
    - enable `secrets`;
    - turn up `medium_items` and/or `small_items`;
    - enable `start_with_keys`; or
    - add more starting maps here.

    If doing the latter, the apworld's best guess at what to set this to is:
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

class StartWithAllMaps(Toggle):
    """
    Whether to start with automaps for all included levels. If off they will be
    added to the pool instead.
    """
    display_name = "Start with all automaps"
    default = True

class UZDoomStartInventory(StartInventory):
    """
    Start with the specified amount of these items. You can list any valid
    inventory item that the game engine understands, even if the randomizer
    doesn't know about it, e.g. "BFG9000: 1" will work even if none of the
    randomized maps contain BFGs.
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


###############################################################################
# Win conditions
###############################################################################

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


###############################################################################
# Combat logic
###############################################################################

def nrof_global_weapons(wad):
    return len({
        item.name() for item in wad.items()
        if item.has_category('weapon') and not item.map})

def nrof_local_weapons(wad):
    return len({
        item.name() for item in wad.items()
        if item.has_category('weapon') and item.map})

class PerMapWeaponUnlocks(Toggle):
    __doc__ = f"""
    Make weapon unlocks per-map instead of global. For example, a shotgun that
    works on MAP01 and a shotgun that works on MAP02 will now be distinct items
    in the pool.

    The `max_weapon_copies` setting is ignored when this is enabled. There will
    always be one copy of each weapon per map.

    In this wad, with default settings, this will add {nrof_local_weapons(wad) - nrof_global_weapons(wad)} progression items to
    the pool. If turning it on, you may need to add additional locations by
    enabling small or medium items, unless you are playing in a multiworld with
    other games that can absorb extra progression items.
    """
    default = False

if wad.has_combat_logic_hints():
    class CombatLogicMode(Choice):
        """
        How the combat logic system works.

        - off: no combat logic. Logic may still require certain weapons for
          certain checks (e.g. rocket launcher for icon of sin).
        - manual: the logic author for this wad has included combat logic data.
          This setting will enable the use of it.
        - auto_per_level: in addition to the manually authored combat logic,
          this will consider weapons logically required for a level if they are
          available anywhere in that level.
        - auto_per_episode: as above, but considers weapons required if they are
          available in a level or any of the preceding levels.
        """
        display_name = "Combat logic mode"
        default = 1
        option_off = 0
        option_manual = 1
        option_auto_per_level = 2
        option_auto_per_episode = 3

        def is_disabled(self):
            return self.value == 0
        def is_enabled(self):
            return not self.is_disabled()
        def is_auto(self):
            return self.value >= 2
else:
    class CombatLogicMode(Choice):
        """
        How the combat logic system works.

        - off: no combat logic. Logic may still require certain weapons for
          certain checks (e.g. rocket launcher for icon of sin).
        - auto_per_level: this will consider weapons logically required for a
          level if they are available anywhere in that level.
        - auto_per_episode: as above, but considers weapons required if they are
          available in a level or any of the preceding levels.
        """
        display_name = "Combat logic mode"
        default = 2
        option_off = 0
        option_auto_per_level = 2
        option_auto_per_episode = 3

        def is_disabled(self):
            return self.value == 0
        def is_enabled(self):
            return not self.is_disabled()
        def is_auto(self):
            return self.value >= 2

class CombatLogicSecrets(Toggle):
    """
    Whether to consider secrets in auto combat logic. If this is off, weapons
    will not be considered logically required unless there is a non-secret way
    to get them.
    """
    display_name = "Auto combat logic uses secrets"
    default = False

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


###############################################################################
# Gameplay settings
###############################################################################

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


###############################################################################
# Rando settings
###############################################################################

def items(*categories):
    return {
        name for category in categories
        for name in included_logic.item_categories_to_names.get(category, [])
    }

def locations(*categories):
    return {
        name for category in categories
        for name in included_logic.location_categories_to_names.get(category, [])
    }

def nrof(*categories):
    return len(locations(*categories))

def names(*categories):
    return ', '.join(sorted(items(*categories)))

def vis(*categories):
    return Visibility.none if not nrof(*categories) else Visibility.all

def size_docs(size):
    return f"""
What percentage of {size} items will be randomized.

This wad contains {nrof(size)} {size} items ({nrof(size+'-secret')} in secrets):
{names(size)}.
"""

def sized_names(size, category):
    # We do this rather than using nrof/names because the categories_to_names
    # maps are very particular about what order you put the category names in
    # when constructing composite keys.
    fqins = items(size) & items(category)
    nlocs = len(locations(size) & locations(category))
    return f'{size} ({nlocs}): {', '.join(sorted(fqins))}.\n' if len(fqins) else ''

def kind_docs(kind):
    return f"""
Whether to include {kind} items in the pool. If off, items of this kind will
not be randomized. If on, they will be, subject to the size settings above.

This wad contains {nrof(kind)} {kind} items ({nrof(kind+'-secret')} in secrets):
{sized_names('big', kind)}{sized_names('medium', kind)}{sized_names('small', kind)}
"""

# Top-level toggle for whether secrets should be excluded.
class IncludeSecrets(Choice):
    __doc__ = f"""
    Whether secret locations are eligible for randomization.

    If off, neither secrets themselves nor the items in them will be randomized.

    If set to `items_only`, items located in secrets will be randomized, but the
    secrets themselves will not be checks.

    If set to `items_and_secrets`, items located in secrets will be randomized,
    and finding the secret itself will also count as a check.

    This wad contains {nrof('secret-sector', 'secret-marker')} secrets and {nrof('secret') - nrof('secret-sector', 'secret-marker')} secret items.
    """
    display_name = "Secrets"
    default = 0
    option_excluded = 0
    option_items_only = 1
    option_items_and_secrets = 2

class IncludeItemAmount(NamedRange):
    range_start = 0
    range_end = 100
    special_range_names = {
        "all": 100,
        "none": 0,
        "shuffle": -1,
        "vanilla": -2,
    }

class IncludeBigItems(IncludeItemAmount):
    __doc__ = f"""{size_docs('big')}
    This option, and the ones below, supports some special values:

    'shuffle' will randomize these items among themselves within your game,
    without adding them to the pool. Unlike using plando to force these items
    local, this will also not generate client messages when collecting them.
    (Tuning data, however, will still be recorded.)

    'vanilla' is similar to 'shuffle', except that each item will be placed at
    its original vanilla location. It is primarily useful to logic developers.
    """
    display_name = "Big items"
    default = 100
    visibility = vis('big')

class IncludeMediumItems(IncludeItemAmount):
    __doc__ = size_docs('medium')
    display_name = "Medium items"
    default = -1
    visibility = vis('medium')

class IncludeSmallItems(IncludeItemAmount):
    __doc__ = size_docs('small')
    display_name = "Small items"
    default = -1
    visibility = vis('small')

class IncludeUnknownSizeItems(IncludeItemAmount):
    __doc__ = f"""
    The logic for this wad contains items of unknown size. Report this to the
    logic developer as a bug.

    This wad contains {nrof('unknown_size')} unknown_size items:
    {names('unknown_size')}.
    """
    display_name = "Unknown-size items"
    default = 100
    visibility = vis('unknown_size')

class IncludeHealthItems(Toggle):
    __doc__ = kind_docs('health')
    display_name = "Health items"
    default = True
    visibility = vis('health')

class IncludeArmorItems(Toggle):
    __doc__ = kind_docs('armor')
    display_name = "Armour items"
    default = True
    visibility = vis('armor')

class IncludeAmmoItems(Toggle):
    __doc__ = kind_docs('ammo')
    display_name = "Ammo items"
    default = True
    visibility = vis('ammo')

class IncludeAttackItems(Toggle):
    __doc__ = kind_docs('attack')
    display_name = "Attack items"
    default = True
    visibility = vis('attack')

class IncludeDefenceItems(Toggle):
    __doc__ = kind_docs('defence')
    display_name = "Defence items"
    default = True
    visibility = vis('defence')

class IncludeToolItems(Toggle):
    __doc__ = kind_docs('tool')
    display_name = "Tool items"
    default = True
    visibility = vis('tool')

class IncludeUnknownKindItems(Toggle):
    __doc__ = f"""
    The logic for this wad contains items of unknown kind. Report this to the
    logic developer as a bug.

    This wad contains {nrof('unknown_kind')} unknown_kind items:
    {names('unknown_kind')}.
    """
    display_name = "Unknown-kind items"
    default = True
    visibility = vis('unknown_kind')

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

class IncludedItemCategories(OptionList):
    """
    This is a setting that offers low-level control over what locations get
    randomized, for situations where the above settings do not suffice.

    Each entry is a category (like 'health' or 'secret-big-armor'), followed by
    ':' and a percentage, e.g. 'health:50' to randomize 50% of all health items.
    See doc/categories.md for a detailed explanation of officially supported
    categories.

    Using an item name, e.g. 'ArmorBonus:none', is also permitted, and will
    match that exact item. To avoid ambiguity, you have to use Doom's internal
    name, e.g. 'ClipBox' instead of 'Bullets' and 'ArtiHealth' instead of
    'Quartz Flask'.

    Instead of a percentage, you can also use 'all', 'none', 'shuffle', or
    'vanilla', with the same meanings as above; or 'start' to place the matching
    items directly into the player's starting inventory, although
    start_inventory_from_pool is preferred for that.

    Entries are checked left to right, with earlier ones taking precedence over
    later ones; locations that match multiple entries will only affected by the
    first one. So, for example, this setting:

        ['health:none', 'small:all', 'ammo:50']

    Would randomize no health of any size, all big items, and 50% of whatever
    ammo is left.

    On a technical level, this setting is checked before anything else,
    including UZArchipelago's built in baseline settings and the toggles above,
    so it offers significant control over how the item and location pools are
    populated, but also makes it easy to write settings that cannot generate.
    """
    display_name = "Included item/location categories"
    default = []

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

class PreTuningMode(Toggle):
    """
    This setting is for logic developers. If enabled, all other options are
    overridden. All checks contain their original items (i.e. there is no
    randomization) and you start with access to all levels, all automaps, and no
    keys. Checks for all difficulties are spawned regardless of what difficulty
    you play on.

    The intent of this mode is to let you play through the game, or specific
    levels, "normally", to generate a tuning file, even in cases where the
    initial scan is so conservative as to cause generation failures.

    Pretuning mode also disables persistent mode and disables automatic MAPINFO
    generation, so the game will retain its original episode divisions,
    intermission text, etc.
    """
    display_name = "Pretuning Mode"
    default = False



@dataclass
class UZDoomOptions(PerGameCommonOptions):
    # Start conditions
    spawn_filter: SpawnFilter
    starting_levels: StartingLevels
    start_with_keys: StartWithKeys
    included_levels: IncludedLevels
    start_with_all_maps: StartWithAllMaps
    start_inventory: UZDoomStartInventory  # replaces stock start_inventory
    # Win conditions
    win_map_count: WinMapCount
    win_map_names: WinMapNames
    # Combat logic
    per_map_weapons: PerMapWeaponUnlocks
    combat_logic_mode: CombatLogicMode
    combat_logic_secrets: CombatLogicSecrets
    # Gameplay
    allow_respawn: AllowRespawn
    full_persistence: FullPersistence
    # Location/item pool control
    secrets: IncludeSecrets
    big_items: IncludeBigItems
    medium_items: IncludeMediumItems
    small_items: IncludeSmallItems
    unknown_size_items: IncludeUnknownSizeItems
    health_items: IncludeHealthItems
    armor_items: IncludeArmorItems
    ammo_items: IncludeAmmoItems
    attack_items: IncludeAttackItems
    defence_items: IncludeDefenceItems
    tool_items: IncludeToolItems
    unknown_kind_items: IncludeUnknownKindItems
    max_weapon_copies: MaxWeaponCopies
    included_item_categories: IncludedItemCategories
    pretuning_mode: PreTuningMode
    # Stock settings
    start_inventory_from_pool: StartInventoryPool

class UZDoomWeb(WebWorld):
  game = f"UZDoom ({wad.name})"
  option_groups = [
    OptionGroup("Starting Conditions", [
        SpawnFilter, StartingLevels, StartWithKeys, IncludedLevels, StartWithAllMaps, UZDoomStartInventory,
    ]),
    OptionGroup("Win Conditions", [
        WinMapCount, WinMapNames,
    ]),
    OptionGroup("Combat Logic", [
        PerMapWeaponUnlocks, CombatLogicMode, CombatLogicSecrets
    ]),
    OptionGroup("Gameplay Settings", [
        AllowRespawn, FullPersistence,
    ]),
    OptionGroup("Randomization Settings", [
        IncludeSecrets, IncludeBigItems, IncludeMediumItems, IncludeSmallItems,
        IncludeHealthItems, IncludeArmorItems, IncludeAmmoItems,
        IncludeAttackItems, IncludeDefenceItems, IncludeToolItems,
        MaxWeaponCopies, IncludedItemCategories, PreTuningMode,
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

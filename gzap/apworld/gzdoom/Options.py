# TODO: add/implement options for:
# - in-level/across-level monster shuffle
# - in-level/across-level minor item shuffle
# - behaviour on death
# - weapon logic
# - win logic: all levels/N levels/all bosses/N bosses
# - are bosses checks
# - are exits checks (in addition to giving you a clear token)
#   we do this by registering multiple checks per level, adding a new API to the
#   generated zscript to register them all, and checking all of them on exit
# - progressive automap -- automaps bind to the first unmapped level you have,
#   and/or you need multiple automaps to display everything for a level (say,
#   one gets you checks, one gets you geometry, one gets you progression hilights)
# - progressive keys -- this will be tricky to implement, I think, but the idea
#   is that keys start out unformed, and the first door you use when having an
#   unformed key specializes it for that door. Alternately, have a menu that
#   lets you intentionally form keys. Adds more choice about what you unlock when.
#   From talking to people on the discord, this (a) has no particular support in
#   AP, you need to implement it yourself and (b) is very hard to get right in
#   ways that are both fun and reliably avoid softlocks. Probably going to avoid
#   this for now.

from math import ceil,floor

from Options import PerGameCommonOptions, Toggle, DeathLink, StartInventoryPool, OptionSet, NamedRange, Range, OptionDict
from dataclasses import dataclass

from . import model
model.init_wads(__package__)

class StartWithAutomaps(Toggle):
    """
    Give the player automaps for all levels from the start.
    Otherwise, they'll be in the pool as useful, but not required, items.
    """
    display_name = "Start with Automaps"
    default = False


class MaxWeaponCopies(Range):
    """
    Applies a hard limit to the number of copies of each weapon in the item pool.

    Lower values mean you may have to wait longer before finding a given weapon,
    but also means more checks will contain health, powerups, etc. rather than
    duplicates of weapons you already have.

    Setting to 0 disables the limit entirely.

    How many copies of each weapon end up in the pool is limited by both this and
    'Levels per weapon copy'; whichever is lower takes precedence. This is an
    upper bound: it will not add more weapons than actually exist in the WAD.
    """
    display_name = "Max weapon copies"
    range_start = 0
    range_end = 32
    default = 4


class LevelsPerWeapon(Range):
    """
    Applies a scaling limit to the number of copies of each weapon in the item pool
    based on how many levels are being played.

    The default (8) means that a "standard" 32-level megawad will be limited to
    at most 4 copies of each weapon. Lower values will increase the limit, higher
    levels will decrease it.

    Setting to 0 disables the limit entirely.

    How many copies of each weapon end up in the pool is limited by both this and
    'Max weapon copies'; whichever is lower takes precedence. This is an
    upper bound: it will not add more weapons than actually exist in the WAD.
    """
    display_name = "Levels per weapon copy"
    range_start = 0
    range_end = 32
    default = 8


class SelectedWad(OptionSet):
    """
    Which WAD to generate for.

    This list is populated from the logic files built in to the apworld. If you
    want to generate a game for something else, see the 'new-wads.md' documentation
    file.

    If you select more than one WAD from this list, it will pick one for you at random.
    """
    display_name = "WAD to play"
    default = set([wad.name for wad in model.wads()])
    valid_keys = [wad.name for wad in model.wads()]

class StartingLevels(OptionSet):
    """
    Set of levels to begin with access to. If you select levels that aren't in the
    WAD you choose (e.g. E1M1 when you're generating for Doom 2) they will be safely
    ignored.

    You will start with the access codes for these levels; if start_with_keys is
    enabled, you will also start with all keys for them.

    If you are playing a multiworld game and want to start with nothing at all
    (i.e. Doom is not playable until another world unlocks it), set this to [].

    This option supports globbing expressions.
    """
    display_name = "Starting levels"
    default = ["E?M1", "MAP01"]
    # valid_keys = model.all_map_names()

class StartWithKeys(Toggle):
    """
    If enabled, you will start with all the keys for any starting level that has
    keys.

    This is on by default because turning it off will cause generation failures
    for newly-scanned wads, or wads where the default starting levels have very
    restrictive item access. For properly tuned wads where at least some checks
    are known to be reachable without keys, turning this off will allow the
    randomizer more freedom in item placement.
    """
    display_name = "Start with keys"
    default = True

class IncludedLevels(OptionSet):
    """
    Set of levels to include in randomization.

    It is safe to select levels not in the target WAD; they will be ignored. Selecting
    no levels is equivalent to selecting all levels.

    The default win condition is to complete all levels, so adding more levels will
    result in a longer game. If you want to play lots of levels but only beat some
    of them, you should also adjust the `win_conditions` option.

    This option supports globbing expressions.
    """
    display_name = "Included levels"
    default = [] # sorted(model.all_map_names())

class ExcludedLevels(OptionSet):
    """
    Set of levels to exclude from randomization.

    This takes precedence over included_levels, if a map appears in both.

    This option supports globbing expressions.
    """
    display_name = "Excluded levels"
    default = ['TITLEMAP']

class SpawnFilter(NamedRange):
    """
    Tell the generator which spawn filter (information about what items and enemies
    spawn in each map) the game will use.

    You need to pick a setting here that matches the difficulty you will be playing
    on. In stock Doom, ITYTD and HNTR use "easy" spawns, HMP uses "medium", and
    UV and NM use "hard".

    If you are playing with a mod that changes this, make sure that you choose the
    filter appropriate to the difficulty level you are selecting. Many gameplay mods
    have custom difficulty settings that are not just simple reskins of the Doom
    ones.
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

class IncludedItemCategories(OptionDict):
    """
    Which item categories to include in randomization. This controls both which
    items are replaced with checks, and what the item pool contains.

    Keys and weapons are always included and cannot be controlled with this
    option. You must enable at least one category here or generation is likely
    to fail.

    For each category, a setting of `1` enables full randomization, and a setting
    of `0` disables randomization completely. Values in between will randomize the
    given proportion, e.g. `"powerup": 0.5` will replace half of the powerups in
    the game with AP checks (and add the original items to the item pool) and
    leave the rest alone.

    See `glossary.md` for a description of the different categories and which
    items they cover.

    Enabling "medium" categories tends to more than double the number of checks.
    Enabling all categories tends to increase it by about 10x. Make sure you (and
    your co-op partners) are prepared for a game with thousands or tens of thousands
    of checks in Doom if you turn these on.
    """
    display_name = "Included item/location categories"
    default = {
        category: 0
        for category in model.all_categories()
        if category not in {"key", "weapon", "token"}
    } | {"powerup": 1, "big-ammo": 1, "big-health": 1, "big-armor": 1, "map": 1}
    valid_keys = model.all_categories() - {"token", "key", "weapon"}

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
    default = 25

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

class WinConditions(OptionDict):
    """
    Win conditions for the randomized game. If multiple conditions are enabled,
    the player is required to satisfy all of them!

        nrof-maps: (int, fraction, or "all")
    Require the player to finish this many levels. If "all", all levels included
    in randomization must be cleared. If set to an integer >= 1, that many
    levels must be cleared. If a fraction, that fraction of levels is required,
    e.g. 0.5 would require you to clear 16 of Doom 2's 32 levels.

        specific-maps: (list of map names)
    Require the player to finish these specific maps. Globbing expressions are
    supported, so `maps: ["E1M?" "E?M8"]` would require the player to beat all
    of episode 1 and all boss maps in Doom 1, for example. Maps listed here that
    don't exist in the selected WAD are ignored.
    """
    display_name = "Win conditions"
    default = {
        "nrof-maps": "all",
        "specific-maps": [],
    }
    valid_keys = {"nrof-maps", "specific-maps"}
    def get_levels_needed(self, world):
        levels_needed = self.value.get("nrof-maps", 0)
        if levels_needed == "all":
            return len(world.maps)
        assert levels_needed >= 0,"nrof-maps win condition must be 'all' or a fraction or an integer >= 0"
        if levels_needed > 0 and levels_needed < 1:
            return ceil(len(world.maps) * levels_needed)
        return min(floor(levels_needed), len(world.maps))

    def get_maplist(self, world):
        return [
            map for map in world.maps
            if world.any_glob_matches(self.value.get("specific-maps", []), map.map)
        ]

    def check_win(self, world, state):
        won = True

        levels_needed = self.get_levels_needed(world)
        if levels_needed > 0:
            won = won and levels_needed <= sum([
                1 for map in world.maps
                if state.has(map.clear_token_name(), world.player)
            ])

        for map in self.get_maplist(world):
            won = won and state.has(map.clear_token_name(), world.player)

        return won

    def template_values(self, world):
        return {
            # These are 0/empty for some reason
            'nrof-maps': self.get_levels_needed(world),
            'specific-maps': [map.map for map in self.get_maplist(world)],
        }

class AllowSecretProgress(Toggle):
    """
    Whether the randomizer will place progression items in locations flagged as
    secret. If disabled, secrets will still be randomized but only filler items
    will be placed there.

    NOTE: How well this works is extremely wad-dependent. Many wads contain
    well-hidden items that are not formally marked as secrets and will not be
    excluded by this setting. Others mark items that are out in the open or even
    mandatory to collect as secrets, which can excessively restrict item placement.

    NOTE: In wads where most of the items in the first level are secret -- including
    Doom 1 and 2 -- turning this off is likely to cause generation failures unless
    you also add more starting levels.
    """
    display_name = "Allow secret progression items"
    default = True

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
    or nothing: there is no way to reset individual levels.

    EXPERIMENTAL FEATURE - HANDLE WITH CARE
    """
    display_name = "Persistent Levels"
    default = False

class PreTuningMode(Toggle):
    """
    This setting is for logic developers. If enabled, most other options are
    overridden; only selected_wad and spawn_filter remain functional. All checks
    contain their original items (i.e. there is no randomization) and you start
    with access to all levels, all automaps, and no keys.

    The intent of this mode is to let you play through the game, or specific
    levels, "normally", to generate a tuning file, even in cases where the
    initial scan is so conservative as to cause generation failures.

    If full_persistence is off, pretuning mode also disables automatic MAPINFO
    generation, so the game will retain its original episode divisions,
    intermission text, etc.
    """
    display_name = "Pretuning Mode"
    default = False

@dataclass
class GZDoomOptions(PerGameCommonOptions):
    # Skill level, WAD, and level selection
    selected_wad: SelectedWad
    spawn_filter: SpawnFilter
    starting_levels: StartingLevels
    included_levels: IncludedLevels
    excluded_levels: ExcludedLevels
    # Ordering and victory control
    level_order_bias: LevelOrderBias
    local_weapon_bias: LocalWeaponBias
    carryover_weapon_bias: GlobalWeaponBias
    win_conditions: WinConditions
    # Location pool control
    included_item_categories: IncludedItemCategories
    allow_secret_progress: AllowSecretProgress
    # Item pool control
    start_with_all_maps: StartWithAutomaps
    start_with_keys: StartWithKeys
    max_weapon_copies: MaxWeaponCopies
    levels_per_weapon: LevelsPerWeapon
    # Other settings
    allow_respawn: AllowRespawn
    full_persistence: FullPersistence
    pretuning_mode: PreTuningMode
    # Stock settings
    # death_link: DeathLink
    start_inventory_from_pool: StartInventoryPool

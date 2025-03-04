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

from Options import PerGameCommonOptions, Toggle, DeathLink, StartInventoryPool, OptionSet, NamedRange, Range
from dataclasses import dataclass

from . import model

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


model.init_wads(__package__)
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
    ignored. If you don't select any levels in your chosen WAD, it will force you
    to start with access to the first level.

    You will begin with the access code and all keys for these levels in your inventory.
    """
    display_name = "Starting levels"
    default = ["E1M1", "MAP01"]
    valid_keys = model.all_map_names()


class IncludedLevels(OptionSet):
    """
    Set of levels to include in randomization.

    It is safe to select levels not in the target WAD; they will be ignored. Selecting
    no levels is equivalent to selecting all levels.

    The win condition (at present) is always "complete all levels", so including more
    levels will generally result in a longer game.
    """
    display_name = "Included levels"
    default = sorted(model.all_map_names())

class ExcludedLevels(OptionSet):
    """
    Set of levels to exclude from randomization.

    This takes precedence over included_levels, if a map appears in both.
    """
    display_name = "Excluded levels"
    default = ['TITLEMAP']

# TODO: this isn't useful until we have multi-difficulty logic files, or a way
# of loading a different logic file per difficulty
class Skill(NamedRange):
    """
    Difficulty level. Equivalent to the `skill` console command (so the range is
    from 0 to 4, not 1 to 5).
    """
    display_name = "Difficulty"
    range_start = 0
    range_end = 4
    default = 2
    special_range_names = {
        "itytd": 0,
        "hntr": 1,
        "hmp": 2,
        "uv": 3,
        "nm": 4
    }

class LevelOrderBias(Range):
    """
    How closely the randomizer tries to follow the original level order of the
    WAD. Internally, this is the % of earlier levels you need to be able to beat
    before it will consider later levels in logic. This is primarily useful for
    enforcing at least a bit of difficulty progression rather than being dumped
    straight from MAP01 to MAP30.

    The default setting of 25%, for example, means it won't expect you to fight
    the Cyberdemon in Doom 1 level 18¹ until you've cleared at least four earlier
    levels, or the Spider Mastermind until you've cleared six.

    ¹ Counting secret levels
    """
    display_name = "Level order bias"
    range_start = 0
    range_end = 100
    default = 25

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

@dataclass
class GZDoomOptions(PerGameCommonOptions):
    # Skill level, WAD, and level selection
    skill: Skill
    selected_wad: SelectedWad
    starting_levels: StartingLevels
    included_levels: IncludedLevels
    excluded_levels: ExcludedLevels
    level_order_bias: LevelOrderBias
    # Location pool control
    allow_secret_progress: AllowSecretProgress
    # Item pool control
    start_with_all_maps: StartWithAutomaps
    max_weapon_copies: MaxWeaponCopies
    levels_per_weapon: LevelsPerWeapon
    # Other settings
    allow_respawn: AllowRespawn
    full_persistence: FullPersistence
    # Stock settings
    death_link: DeathLink
    start_inventory_from_pool: StartInventoryPool

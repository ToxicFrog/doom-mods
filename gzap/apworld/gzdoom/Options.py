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


model.init_wads(__package__)
class SelectedWad(OptionSet):
    """
    Which WAD to generate for.

    This list is populated from the logic files built in to the apworld. If you want
    to generate something else, generate locally and set theGZAP_CUSTOM_LOGIC_FILE
    environment variable.

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
    display_name = "Starting Levels"
    # default = ["E1M1", "MAP01", "LEVEL01", "PL_MAP01", "TN_MAP01"]
    default = ["MAP01"]
    valid_keys = model.all_map_names()


class IncludedLevels(OptionSet):
    """
    Set of levels to include in randomization.

    It is safe to select levels not in the target WAD; they will be ignored. Selecting
    no levels is equivalent to selecting all levels.

    The win condition (at present) is always "complete all levels", so including more
    levels will generally result in a longer game.
    """
    display_name = "Included Levels"
    default = sorted(model.all_map_names())

class ExcludedLevels(OptionSet):
    """
    Set of levels to exclude from randomization.

    This takes precedence over included_levels, if a map appears in both.
    """
    display_name = "Excluded Levels"
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
    display_name = "Level Order Bias"
    range_start = 0
    range_end = 100
    default = 25

@dataclass
class GZDoomOptions(PerGameCommonOptions):
    start_inventory_from_pool: StartInventoryPool
    start_with_all_maps: StartWithAutomaps
    death_link: DeathLink
    starting_levels: StartingLevels
    included_levels: IncludedLevels
    excluded_levels: ExcludedLevels
    selected_wad: SelectedWad
    level_order_bias: LevelOrderBias
    skill: Skill

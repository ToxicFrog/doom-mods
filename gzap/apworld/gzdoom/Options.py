# TODO: add/implement options for:
# - in-level/across-level monster shuffle
# - in-level/across-level minor item shuffle
# - automaps (at start, in pool, vanilla, none)
# - behaviour on death
# - levels to exclude from the randomizer
# - levels to start with
# - weapon logic
# - win logic: all levels/N levels/all bosses/N bosses
# - are bosses checks
# - are exits checks (in addition to giving you a clear token)

import typing

from Options import PerGameCommonOptions, Toggle, DeathLink, StartInventoryPool, FreeText, OptionSet, NamedRange
from dataclasses import dataclass

from . import model

class StartWithAutomaps(Toggle):
    """
    Give the player automaps for all levels from the start.
    Otherwise, they'll be in the pool as useful, but not required, items.
    """
    # TODO: implement this
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


@dataclass
class GZDoomOptions(PerGameCommonOptions):
    start_inventory_from_pool: StartInventoryPool
    start_with_all_maps: StartWithAutomaps
    death_link: DeathLink
    starting_levels: StartingLevels
    included_levels: IncludedLevels
    selected_wad: SelectedWad
    # skill: Skill

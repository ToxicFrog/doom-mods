import typing

from Options import PerGameCommonOptions, Choice, Toggle, DeathLink, StartInventoryPool, FreeText
from dataclasses import dataclass


class RandomMonsters(Choice):
    """
    Choose how monsters are randomized.
    vanilla: use original map placement
    shuffle: monsters are randomly shuffled within each level
    """
    # TODO: implement this
    display_name = "Random Monsters"
    option_vanilla = 0
    option_shuffle = 1
    default = 1


class RandomItems(Choice):
    """
    Choose how "minor" items not included in the main pool are randomized.
    vanilla: use original map placement
    shuffle: items are shuffled within the level
    """
    # TODO: implement this
    display_name = "Random Pickups"
    option_vanilla = 0
    option_shuffle = 1
    default = 1


class StartWithAutomaps(Toggle):
    """
    Give the player automaps for all levels from the start.
    Otherwise, they'll be in the pool as useful, but not required, items.
    """
    # TODO: implement this
    display_name = "Start With All Maps"


class ResetLevels(Choice):
    """
    Choose when levels reset. (You can always manually reset a level from the menu.)
    never: only when you explicitly request a reset
    on death: when you die, the level resets and you restart from the beginning
    on exit: when you exit to the hub, the level resets and you restart next time you enter it
    both: on death + on exit
    """
    # TODO: implement this
    display_name = "Reset Levels"
    option_never = 0
    option_on_death = 1
    option_on_exit = 2
    option_both = 3
    default = 0


class StartingLevels(FreeText):
    """
    Whitespace-separated list of levels to begin with access to. Levels not present in the WAD
    are safely ignored. If you don't list any levels (or if none of the ones you list exist), the
    randomizer will pick the first level it sees.

    You will begin with the access code and all keys for these levels.
    """
    # TODO: implement this
    display_name = "Starting Levels"
    default = "E1M1 MAP01 TN_MAP01 PL_MAP01"


class IncludedLevels(FreeText):
    """
    Whitespace-separated list of levels to include in randomization. Levels not listed here
    will not have checks placed in them and will be hidden from the level select.

    You can use * for simple wildcards, so "E1M* MAP0* MAP10" will include all of Episode 1
    from Doom 1, and the first ten maps from Doom 2.

    If left blank, every available level will be randomized.

    The win condition (at present) is always "complete all levels", so including more levels
    will always result in a longer game.
    """
    # TODO: implement this
    display_name = "Included Levels"
    default = "E* MAP* TN_MAP* PL_MAP*"


@dataclass
class GZDoomOptions(PerGameCommonOptions):
    start_inventory_from_pool: StartInventoryPool
    random_monsters: RandomMonsters
    random_items: RandomItems
    start_with_computer_area_maps: StartWithAutomaps
    death_link: DeathLink
    reset_levels: ResetLevels
    starting_levels = StartingLevels
    included_levels = IncludedLevels

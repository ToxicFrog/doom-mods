import typing

from Options import PerGameCommonOptions, Choice, Toggle, DeathLink, DefaultOnToggle, StartInventoryPool
from dataclasses import dataclass


class RandomMonsters(Choice):
    """
    Choose how monsters are randomized.
    vanilla: use original map placement
    shuffle: monsters are randomly shuffled within each level
    """
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
    display_name = "Random Pickups"
    option_vanilla = 0
    option_shuffle = 1
    default = 1


class StartWithComputerAreaMaps(Toggle):
    """Give the player all Computer Area Map items from the start."""
    display_name = "Start With Computer Area Maps"


class ResetLevels(Choice):
    """
    Choose when levels reset. (You can always manually reset a level from the menu.)
    never: only when you explicitly request a reset
    on death: when you die, the level resets and you restart from the beginning
    on exit: when you exit to the hub, the level resets and you restart next time you enter it
    both: on death + on exit
    """
    display_name = "Reset Levels"
    option_never = 0
    option_on_death = 1
    option_on_exit = 2
    option_both = 3
    default = 0


@dataclass
class GZDoomOptions(PerGameCommonOptions):
    start_inventory_from_pool: StartInventoryPool
    random_monsters: RandomMonsters
    random_items: RandomItems
    start_with_computer_area_maps: StartWithComputerAreaMaps
    death_link: DeathLink
    reset_levels: ResetLevels
    # TODO: allow selecting what subset of levels to play, ideally with an
    # OptionSet if we can populate that from the JSON before generation time.
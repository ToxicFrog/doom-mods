import math
import sys
from dataclasses import dataclass

from worlds.AutoWorld import World, WebWorld
from Options import PerGameCommonOptions, Toggle, DeathLink, StartInventoryPool, OptionSet, NamedRange, Range, OptionDict, OptionList, OptionError, Visibility, OptionGroup

if 'worlds.uzdoom' not in sys.modules:
  raise RuntimeError(f'Unable to load supporting libraries -- make sure that `uzdoom.apworld` is installed!')

uzdoom = sys.modules['worlds.uzdoom']
model = sys.modules['worlds.uzdoom.model']
options = sys.modules['worlds.uzdoom.Options']

included_logic = model.init_wads(__package__)
wad = included_logic.wad

class IncludedLevels(options.IncludedLevels):
  __doc__ = options.IncludedLevels.__doc__
  default = sorted(wad.maps.keys())

default_solo_starting_maps = wad.default_solo_starting_maps()
class StartingLevels(options.StartingLevels):
  __doc__ = options.StartingLevels.__doc__ + (
    '' if not default_solo_starting_maps
    else f'''
    For solo play, to avoid generation failures due to a small sphere 1 in
    this wad, you may need to either change included_item_categories to enable
    more item categories, or add more maps here. If doing the latter, the
    apworld's best guess at what to set this to is:
    {default_solo_starting_maps}
    '''
  )
  default = sorted(map.map for map in wad.default_starting_maps())

if wad.get_flag('use_hub_logic'):
  class StartWithKeys(options.StartWithKeys):
    '''Forced off because this WAD uses hub logic.'''
    default = False
    visibility = Visibility.none
elif model.tuning_files(wad.package, wad.name):
  class StartWithKeys(options.StartWithKeys):
    __doc__ = options.StartWithKeys.__doc__
    default = False
else:
  class StartWithKeys(options.StartWithKeys):
    __doc__ = options.StartWithKeys.__doc__ + '''
    This WAD lacks tuning data, so setting this to false may cause
    generation failures, especially in singleplayer.
    '''
    default = True

class WinMapCount(options.WinMapCount):
  __doc__ = options.WinMapCount.__doc__
  default = len(wad.all_winnable_map_names())
  range_start = 0
  range_end = len(wad.all_winnable_map_names())

class WinMapNames(options.WinMapNames):
  __doc__ = options.WinMapNames.__doc__
  default = sorted([map for map in wad.all_boss_map_names()])
  valid_keys = sorted([map for map in wad.all_winnable_map_names()])

class MaxWeaponCopies(options.MaxWeaponCopies):
  __doc__ = options.MaxWeaponCopies.__doc__
  default = math.ceil(len(wad.maps)/8)
  range_start = 0
  range_end = 32

if wad.get_flag('use_hub_logic'):
  class LevelOrderBias(options.LevelOrderBias):
    default = 0
    visibility = Visibility.none
else:
  LevelOrderBias = options.LevelOrderBias


@dataclass
class UZDoomOptions___WAD__(options.UZDoomOptions):
  included_levels: IncludedLevels
  starting_levels: StartingLevels
  start_with_keys: StartWithKeys
  win_map_count: WinMapCount
  win_map_names: WinMapNames
  max_weapon_copies: MaxWeaponCopies
  level_order_bias: LevelOrderBias

grouped_option_types = [
  field.type for field in UZDoomOptions___WAD__.__dataclass_fields__.values()
  if hasattr(field.type, 'group_name')
]

class UZDoomWeb___WAD__(WebWorld):
  game = f"UZDoom ({wad.name})"
  option_groups = [
    OptionGroup(option_group_name, [
      option_type for option_type in grouped_option_types
      if option_type.group_name == option_group_name
    ])
    for option_group_name in [
      "Starting Conditions", "Win Conditions", "Combat Logic",
      "Gameplay Settings", "Item Randomization"
    ]
  ]


class UZDoomWorld___WAD__(uzdoom.UZDoomWorld):
  game = f"UZDoom ({wad.name})"
  mod_version = "__VERSION__"
  hidden = False
  wad_logic = wad
  options_dataclass = UZDoomOptions___WAD__
  options: UZDoomOptions___WAD__
  web: WebWorld = UZDoomWeb___WAD__()

  # Used by AP itself
  item_name_to_id = model.unified_item_map(included_logic)
  item_name_groups = model.unified_item_groups(included_logic)
  location_name_to_id = model.unified_location_map(included_logic)
  location_name_groups = model.unified_location_groups(included_logic)

import math
import sys
from dataclasses import dataclass
from importlib import resources

from worlds.AutoWorld import World, WebWorld

VERSION = resources.read_text(__package__, "VERSION").strip()
# print(f"{__package__}: UZArchipelago wad apworld version {VERSION}")

if 'worlds.uzdoom' not in sys.modules:
  raise RuntimeError(f'Unable to load supporting libraries -- make sure that `uzdoom.apworld` is installed!')

uzdoom = sys.modules['worlds.uzdoom']
model = sys.modules['worlds.uzdoom.model']
included_logic = model.init_wads(__package__)
wad = included_logic.wad

from .Options import UZDoomOptions, UZDoomWeb

if uzdoom.VERSION != VERSION:
  print(f"Warning: {__package__}: version mismatch between core apworld ({uzdoom.VERSION}) and wad apworld ({VERSION})")

class UZDoomWorld___WAD__(uzdoom.UZDoomWorld):
  game = f"UZDoom ({wad.name})"
  mod_version = VERSION
  hidden = False
  wad_logic = wad
  options_dataclass = UZDoomOptions
  options: UZDoomOptions
  web: WebWorld = UZDoomWeb()

  # Used by AP itself
  item_name_to_id = model.unified_item_map(included_logic)
  item_name_groups = model.unified_item_groups(included_logic)
  location_name_to_id = model.unified_location_map(included_logic)
  location_name_groups = model.unified_location_groups(included_logic)

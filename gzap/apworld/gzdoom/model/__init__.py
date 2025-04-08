"""
Data model for information read from the logic file emitted by the scan/tune process.

This contains all the information we use to generate the randomized game: check
locations, what items they originally contained, what to populate the item pool
with, what keys are needed to access what locations, etc.
"""

import json
from importlib import resources
import itertools
import os
from typing import Dict
from pathlib import Path

import Utils

from .DoomItem import *
from .DoomLocation import *
from .DoomMap import *
from .DoomWad import *
from .DoomLogic import *


_DOOM_LOGIC: DoomLogic = DoomLogic()


class WadLogicLoader:
    logic: DoomLogic
    name: str
    wad: DoomWad

    def __init__(self, logic: DoomLogic, name: str):
        self.logic = logic
        self.name = name
        self.wad = DoomWad(self.name, self.logic)

    def __enter__(self):
        return self

    def __exit__(self, err_type, err_value, err_stack):
        if err_type is not None:
            return False

        self.wad.finalize_all()
        self.logic.add_wad(self.name, self.wad)
        return True

    def load_logic(self, name: str, buf: str):
      for idx,line in enumerate(buf.splitlines()):
        if not line.startswith("AP-"):
            continue

        try:
            [evt, payload] = line.split(" ", 1)
            payload = json.loads(payload)

            if evt == "AP-MAP":
                self.wad.new_map(payload)
            elif evt == "AP-ITEM":
                self.wad.new_item(payload)
            elif evt == "AP-SCAN-DONE":
                self.wad.finalize_scan(payload)
            elif evt == "AP-CHECK":
                self.wad.tune_location(**payload)
            elif evt == "AP-SECRET":
                self.wad.new_secret(payload)
            else:
                # AP-XON, AP-ACK, AP-STATUS, AP-CHAT, and other multiplayer-only messages
                pass

        except Exception as e:
            raise ValueError(f"Error loading logic/tuning for {name} on line {idx}:\n{line}") from e


_init_done: bool = False

def add_wad(name: str):
    return WadLogicLoader(_DOOM_LOGIC, name)

def get_wad(name: str) -> DoomWad:
    assert _init_done
    return _DOOM_LOGIC.wads[name]

def print_wad_stats(name: str, wad: DoomWad) -> None:
    if "GZAP_DEBUG" not in os.environ:
        return
    nrof_maps = len(wad.all_maps())
    nrof_monsters = sum(map.monster_count for map in wad.all_maps())
    assert nrof_maps > 0,f"The logic for WAD {name} defines no maps."
    print("\x1B[1m%32s: %2d maps, %4d monsters; %4d monsters/map\x1B[0m" % (
        name, nrof_maps, nrof_monsters, nrof_monsters//nrof_maps))
    for sknum, skname in [(3, "UV")]: # [(1, "HNTR"), (2, "HMP"), (3, "UV")]:
      pool = wad.stats_pool(sknum)
      num_items = sum(pool.item_counts.values())
      num_p = sum(pool.progression_items().values())
      num_locs = len(pool.locations)
      num_secrets = len([loc for loc in pool.locations if loc.secret])
      print("%32s  %4d locs (%3d secret), %4d items (%4d progression)" % (
          skname, num_locs, num_secrets, num_items, num_p))

def logic_files(package):
    """
    Returns a list of (wad-name, logic-file) pairs. This is drawn from all files
    in the apworld's logic/ directory, plus all files in the user's
    Archipelago/gzdoom/logic directory, sorted by wad name.

    If a logic file exists in both places, only the external one is loaded.

    File extensions, if present, are ignored; the wad name is everything in the
    filename up to the first '.'.
    """
    logic = {}
    for logic_file in resources.files(package).joinpath("logic").iterdir():
        logic[logic_file.name.split(".")[0]] = logic_file
    for logic_file in (Path(Utils.home_path()) / "gzdoom" / "logic").iterdir():
        if logic_file.is_file():
            logic[logic_file.name.split(".")[0]] = logic_file

    return sorted(logic.items())


def tuning_files(package, wad):
    """
    Return a list of all tuning files for a given wad.

    Tuning files are returned in a defined order: sorted by filename, with all
    internal files sorted before all external files.
    """
    internal = [
        p for p in resources.files(package).joinpath("tuning").iterdir()
        if p.is_file() and (p.name == wad or p.name.startswith(f"{wad}."))
    ]
    external = [
        p for p in (Path(Utils.home_path()) / "gzdoom" / "tuning").iterdir()
        if p.is_file() and (p.name == wad or p.name.startswith(f"{wad}."))
    ]
    return sorted(internal) + sorted(external)

def init_wads(package):
  global _init_done
  if _init_done:
      return
  _init_done = True

  gzd_dir = os.path.join(Utils.home_path(), "gzdoom")
  os.makedirs(os.path.join(gzd_dir, "logic"), exist_ok=True) # in-dev logic files
  os.makedirs(os.path.join(gzd_dir, "tuning"), exist_ok=True) # in-dev tuning files

  # Load all logic files included in the apworld.
  for wadname,logic_file in logic_files(package):
    #   print(f"Loading logic for {wadname} from {logic_file}")
      buf = logic_file.read_text()
      for tuning_file in tuning_files(package, wadname):
        #   print(f"  + tuning from {tuning_file}")
          buf = buf + "\n" + tuning_file.read_text()
      with add_wad(wadname) as wadloader:
          wadloader.load_logic(logic_file.name, buf)
          print_wad_stats(wadloader.name, wadloader.wad)


def wads() -> List[DoomWad]:
    return sorted(_DOOM_LOGIC.wads.values(), key=lambda w: w.name)

def all_map_names() -> Set[str]:
    names = set()
    for wad in wads():
        names.update([map.map for map in wad.all_maps()])
    return names

def all_categories() -> FrozenSet[str]:
    return frozenset(unified_item_groups().keys()) | frozenset(unified_location_groups().keys())

def unified_item_map():
    return _DOOM_LOGIC.item_names_to_ids.copy()

def unified_item_groups():
    return _DOOM_LOGIC.item_categories_to_names.copy()

def unified_location_map():
    return _DOOM_LOGIC.location_names_to_ids.copy()

def unified_location_groups():
    return _DOOM_LOGIC.location_categories_to_names.copy()

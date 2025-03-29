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

def count_items(sk, items) -> int:
    n = 0
    for item in items:
        if item.is_default_enabled():
            n = n + item.count.get(sk, 0)
    return n

def print_wad_stats(name: str, wad: DoomWad) -> None:
    if "GZAP_DEBUG" not in os.environ:
        return
    print("%32s: %d maps" % (name, len(wad.all_maps())))
    for sknum, skname in [(1, "HNTR"), (2, "HMP"), (3, "UV")]:
      num_p = count_items(sknum, wad.progression_items(sknum))
      num_u = count_items(sknum, wad.useful_items(sknum))
      num_f = count_items(sknum, wad.filler_items(sknum))
      locs = [loc for loc in wad.locations(sknum) if loc.orig_item.is_default_enabled()]
      print("%32s  %4d locs (%3d secret), %4d items (P:%-4d + U:%-4d + F:%-4d)" % (
          skname, len(locs), len([loc for loc in locs if loc.secret]),
          num_p + num_u + num_f, num_p, num_u, num_f
      ))

def logic_files(package):
    """
    Return a list of all logic files. This is all files in the apworld's logic/
    directory, plus all files (if any) in the Archipelago/gzdoom/logic/ directory.

    If a file with the same name exists in both places, only the latter is loaded.
    """
    logic = {}
    for logic_file in resources.files(package).joinpath("logic").iterdir():
        logic[logic_file.name] = logic_file
    for logic_file in (Path(Utils.home_path()) / "gzdoom" / "logic").iterdir():
        if logic_file.is_file():
            logic[logic_file.name] = logic_file

    return sorted(logic.values(), key=lambda p: p.name)


def tuning_files(package, wad):
    """
    Return a list of all tuning files for a given wad.
    """
    internal = resources.files(package).joinpath("tuning").joinpath(wad)
    external = Path(Utils.home_path()) / "gzdoom" / "tuning" / wad
    return [
        p for p in [internal, external]
        if p.is_file()
    ]

def init_wads(package):
  global _init_done
  if _init_done:
      return
  _init_done = True

  gzd_dir = os.path.join(Utils.home_path(), "gzdoom")
  os.makedirs(os.path.join(gzd_dir, "logic"), exist_ok=True) # in-dev logic files
  os.makedirs(os.path.join(gzd_dir, "tuning"), exist_ok=True) # in-dev tuning files

  # Load all logic files included in the apworld.
  # Sort them so we get a consistent order, and thus consistent ID assignment,
  # across runs.
  # TODO: maybe separate logic and tuning directories or similar?
  for logic_file in logic_files(package):
    #   print("Loading logic:", logic_file.name)
      buf = logic_file.read_text()
      for tuning_file in tuning_files(package, logic_file.name):
        #   print("Loading tuning:", tuning_file)
          buf = buf + "\n" + tuning_file.read_text()
      with add_wad(logic_file.name) as wadloader:
          wadloader.load_logic(logic_file.name, buf)
          print_wad_stats(wadloader.name, wadloader.wad)


def wads() -> List[DoomWad]:
    return sorted(_DOOM_LOGIC.wads.values(), key=lambda w: w.name)

def all_map_names() -> Set[str]:
    names = set()
    for wad in wads():
        names.update([map.map for map in wad.all_maps()])
    return names

def all_item_categories() -> FrozenSet[str]:
    return frozenset(unified_item_groups().keys())

def unified_item_map():
    return _DOOM_LOGIC.item_names_to_ids.copy()

def unified_item_groups():
    return _DOOM_LOGIC.item_categories_to_names.copy()

def unified_location_map():
    return _DOOM_LOGIC.location_names_to_ids.copy()

def unified_location_groups():
    return _DOOM_LOGIC.location_categories_to_names.copy()

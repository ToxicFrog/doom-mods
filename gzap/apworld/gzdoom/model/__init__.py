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

from .DoomItem import *
from .DoomLocation import *
from .DoomMap import *
from .DoomWad import *
from .DoomLogic import *


_DOOM_LOGIC: DoomLogic = DoomLogic()


class UnsupportedScanEventError(NotImplementedError):
    pass


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

    def load_logic(self, buf: str):
      for line in buf.splitlines():
        if not line.startswith("AP-"):
            continue

        [evt, payload] = line.split(" ", 1)
        payload = json.loads(payload)
        # print(evt, payload)

        if evt == "AP-MAP":
            self.wad.new_map(payload)
        elif evt == "AP-ITEM":
            self.wad.new_item(payload)
        elif evt == "AP-SCAN-DONE":
            self.wad.finalize_scan(payload)
        elif evt == "AP-CHECK":
            self.wad.tune_location(**payload)
        elif evt in {"AP-XON", "AP-ACK"}:
            # used only for multiplayer
            pass
        else:
            # Unsupported event type
            raise UnsupportedScanEventError(evt)


_init_done: bool = False

def add_wad(name: str):
    return WadLogicLoader(_DOOM_LOGIC, name)

def get_wad(name: str) -> DoomWad:
    assert _init_done
    return _DOOM_LOGIC.wads[name]

def init_wads(package):
  global _init_done
  if _init_done:
      return
  _init_done = True

  # Debug/test mode: load the specifed file and nothing else.
  if "GZAP_LOGIC_FILE" in os.environ:
      path = os.environ["GZAP_LOGIC__FILE"]
      print(f"Loading external WAD logic from {path}")
      with open(path) as fd:
          buf = fd.read()
      with add_wad(os.path.basename(path)) as wad:
          wad.load_logic(buf)
      return

  # Load all logic files included in the apworld.
  # Sort them so we get a consistent order, and thus consistent ID assignment,
  # across runs.
  # TODO: maybe separate logic and tuning directories or similar?
  print("Looking for builtin logic files in", __spec__)
  for logic_file in sorted(resources.files(package).joinpath("logic").iterdir(), key=lambda p: p.name):
      with add_wad(logic_file.name) as wad:
          print(f"Loading builtin WAD logic from {logic_file.name}")
          wad.load_logic(logic_file.read_text())

def wads() -> List[DoomWad]:
    return sorted(_DOOM_LOGIC.wads.values(), key=lambda w: w.name)

def all_map_names() -> Set[str]:
    names = set()
    for wad in wads():
        names.update([map.map for map in wad.all_maps()])
    return names

def unified_item_map():
    return _DOOM_LOGIC.item_names_to_ids.copy()

def unified_location_map():
    return _DOOM_LOGIC.location_names_to_ids.copy()

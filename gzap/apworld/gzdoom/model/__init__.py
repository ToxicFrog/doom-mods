"""
Data model for information read from the logic file emitted by the scan/tune process.

This contains all the information we use to generate the randomized game: check
locations, what items they originally contained, what to populate the item pool
with, what keys are needed to access what locations, etc.
"""

import json
import os
from typing import Dict

from .DoomItem import *
from .DoomLocation import *
from .DoomMap import *
from .DoomWad import *


class DoomLogic:
    wads: Dict[str,DoomWad]

    def __init__(self):
        self.wads = {}

    def add_wad(self, name: str, wad: DoomWad):
        self.wads[name] = wad


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
        self.wad = DoomWad()

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


def add_wad(name: str):
    return WadLogicLoader(_DOOM_LOGIC, name)

def get_wad(name: str) -> DoomWad:
    return _DOOM_LOGIC.wads[name]

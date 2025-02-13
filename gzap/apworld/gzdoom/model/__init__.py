"""
Data model for information read from the logic file emitted by the scan/tune process.

This contains all the information we use to generate the randomized game: check
locations, what items they originally contained, what to populate the item pool
with, what keys are needed to access what locations, etc.
"""

import json
import os
import settings
import Utils

from .DoomItem import *
from .DoomLocation import *
from .DoomMap import *
from .DoomLogic import *


class UnsupportedScanEventError(NotImplementedError):
    pass


def get_logic_file_path(file_name: str = "") -> str:
    options = settings.get_settings()
    if not file_name:
        file_name = options["gzdoom_options"]["wad_info_file"]
    if not os.path.exists(file_name):
        file_name = Utils.user_path(file_name)
    return file_name


def load_logic(file_name: str = "") -> DoomLogic:
    print("Loading logic from", get_logic_file_path(file_name))
    logic: DoomLogic = DoomLogic()

    with open(get_logic_file_path(file_name), "r") as fd:
        for line in fd:
            if not line.startswith("AP-"):
                continue

            [evt, payload] = line.split(" ", 1)
            payload = json.loads(payload)
            # print(evt, payload)

            if evt == "AP-MAP":
                logic.new_map(payload)
            elif evt == "AP-ITEM":
                logic.new_item(payload)
            elif evt == "AP-SCAN-DONE":
                logic.finalize_scan(payload)
            elif evt == "AP-CHECK":
                logic.tune_location(**payload)
            elif evt in {"AP-XON", "AP-ACK"}:
                # used only for multiplayer
                pass
            else:
                # Unsupported event type
                raise UnsupportedScanEventError(evt)

    logic.finalize_all()
    return logic

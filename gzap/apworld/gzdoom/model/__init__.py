"""
Data model for information read from the logic file emitted by the scan/tune process.

This contains all the information we use to generate the randomized game: check
locations, what items they originally contained, what to populate the item pool
with, what keys are needed to access what locations, etc.
"""

from importlib import resources
import os
from pathlib import Path
import re

import Utils

from .DoomItem import *
from .DoomLocation import *
from .DoomMap import *
from .DoomWad import *
from .DoomLogic import *
from .WadLogicLoader import *

_DOOM_LOGIC: DoomLogic = DoomLogic()


_init_done: bool = False

def add_wad(name: str, apworld_mtime: int, is_external: bool):
    return WadLogicLoader(_DOOM_LOGIC, name, apworld_mtime, is_external)

def get_wad(name: str) -> DoomWad:
    assert _init_done
    return _DOOM_LOGIC.wads[name]

def logic_files(package):
    """
    Returns (list of internal logic files, list of external logic files). This
    is drawn from all files in the apworld's logic/ directory, plus all files in
    the user's Archipelago/gzdoom/logic directory, sorted by wad name.

    If a logic file exists in both places, both are loaded, but the external one
    takes precedence; the internal one is used only for ID allocation
    consistency.

    File extensions, if present, are ignored; the wad name is everything in the
    filename up to the first '.'.
    """
    internal = [
        file for file in resources.files(package).joinpath("logic").iterdir()
    ]
    external = [
        file for file in (Path(Utils.home_path()) / "gzdoom" / "logic").iterdir()
        if file.is_file()
    ]
    return sorted(internal, key=lambda f: f.name), sorted(external)

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
    return sorted(internal, key=lambda f: f.name) + sorted(external)

def init_wad(package, logic_file, is_external, apworld_mtime):
    wadname = logic_file.name.split(".")[0]
    with add_wad(wadname, apworld_mtime, is_external) as wadloader:
        wadloader.load_all(logic_file, tuning_files(package, wadname))
        wadloader.print_stats(is_external)

def package_timestamp(package):
    apworld_path = re.sub(r'\.apworld.*', '.apworld', str(resources.files(package)))
    return os.path.getmtime(apworld_path)

def init_wads(package):
    global _init_done
    if _init_done:
        return
    _init_done = True

    gzd_dir = os.path.join(Utils.home_path(), "gzdoom")
    os.makedirs(os.path.join(gzd_dir, "logic"), exist_ok=True) # in-dev logic files
    os.makedirs(os.path.join(gzd_dir, "tuning"), exist_ok=True) # in-dev tuning files

    internal, external = logic_files(package)
    # Load all logic files included in the apworld.
    for logic_file in internal:
        init_wad(package, logic_file, False, package_timestamp(package))
    for logic_file in external:
        init_wad(package, logic_file, True, 0)

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

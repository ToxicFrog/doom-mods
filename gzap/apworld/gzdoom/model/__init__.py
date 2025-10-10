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


def add_wad(name: str, apworld_mtime: int, is_external: bool):
    return WadLogicLoader(_DOOM_LOGIC, name, apworld_mtime, is_external)

def get_wad(name: str) -> DoomWad:
    assert _init_done
    return _DOOM_LOGIC.wads[name]

def logic_files(package):
    """
    Get a list of logic files contained in an apworld or on disk, sorted by
    name.

    If package is None, looks in $AP/gzdoom/logic. Otherwise, looks in the
    apworld's /logic directory. The package must be an already-loaded apworld.

    File extensions, if present, are ignored; the wad name is everything in the
    filename up to the first '.'.
    """
    if package:
        return sorted([
            file for file in resources.files(package).joinpath("logic").iterdir()
        ], key=lambda f: f.name)
        # return sorted(files, key=lambda f: f.name)
    else:
        return sorted([
            file for file in (Path(Utils.home_path()) / "gzdoom" / "logic").iterdir()
            if file.is_file()
        ])

def tuning_files(package, wad):
    """
    Return a list of all tuning files for a given wad in a given package (or in
    the AP directory, similar to logic_files).

    Note that only tuning files colocated with the logic file are returned, i.e.
    a logic file in an apworld will only return tuning files in that apworld.

    Tuning files are returned sorted by filename. With the default naming scheme
    used by the client, this means later tuning files will sort after (and
    override) earlier ones.
    """
    if package:
        return sorted([
            p for p in resources.files(package).joinpath("tuning").iterdir()
            if p.is_file() and (p.name == wad or p.name.startswith(f"{wad}."))
        ], key=lambda f: f.name)
    else:
        return sorted([
            p for p in (Path(Utils.home_path()) / "gzdoom" / "tuning").iterdir()
            if p.is_file() and (p.name == wad or p.name.startswith(f"{wad}."))
        ])
    # return sorted(internal, key=lambda f: f.name) + sorted(external)

def init_wad(package, logic_file, is_external, apworld_mtime):
    wadname = logic_file.name.split(".")[0]
    with add_wad(wadname, apworld_mtime, is_external) as wadloader:
        wadloader.load_all(logic_file, tuning_files(package, wadname))
        wadloader.print_stats(is_external)

def package_timestamp(package):
    apworld_path = re.sub(r'\.apworld.*', '.apworld', str(resources.files(package)))
    return os.path.getmtime(apworld_path)

def print_header(package):
    if "GZAP_DEBUG" not in os.environ:
        return
    print('%32s \x1B[4m[ logic from %s ]\x1B[0m' % ('', package))

def init_wads(package):
    if not package:
        gzd_dir = os.path.join(Utils.home_path(), "gzdoom")
        print_header(gzd_dir)
        os.makedirs(os.path.join(gzd_dir, "logic"), exist_ok=True) # in-dev logic files
        os.makedirs(os.path.join(gzd_dir, "tuning"), exist_ok=True) # in-dev tuning files
        ts = 0
    else:
        print_header(package)
        ts = package_timestamp(package)

    logic = logic_files(package)
    for logic_file in logic:
        init_wad(package, logic_file, package is None, ts)

def init_all_wads():
    import time
    now = time.monotonic()
    init_wads('worlds.gzdoom')

    try:
        import worlds.ap_gzdoom_featured
        init_wads('worlds.ap_gzdoom_featured')
    except ModuleNotFoundError:
        print

    try:
        import worlds.ap_gzdoom_extras
        init_wads('worlds.ap_gzdoom_extras')
    except ModuleNotFoundError:
        pass

    init_wads(None)
    print("time:", time.monotonic() - now)

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

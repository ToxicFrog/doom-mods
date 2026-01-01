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


def get_tuned_wad(wad: DoomWad) -> DoomWad:
    if wad.tuned:
        return wad
    with WadTuningLoader(wad) as wadloader:
        wad.tuned = True
        wadloader.load_tuning(tuning_files(wad.package, wad.name))
    return wad

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
    else:
        return sorted([
            file for file in (Path(Utils.user_path()) / "gzdoom" / "logic").iterdir()
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
        tuning_dir = resources.files(package).joinpath("tuning")
    else:
        tuning_dir = Path(Utils.user_path()) / "gzdoom" / "tuning"

    if not tuning_dir.is_dir():
        # No tuning data for this wad!
        return []

    return sorted([
        p for p in tuning_dir.iterdir()
        if package or (p.is_file() and (p.name == wad or p.name.startswith(f"{wad}.")))
    ], key=lambda f: f.name)

def init_wad(logic, package, logic_files):
    wadname = logic_files[0].name.split(".")[0]
    with WadLogicLoader(logic, wadname, package) as wadloader:
        for file in logic_files:
            wadloader.load_logic(file)

def print_header(package):
    if "GZAP_DEBUG" not in os.environ:
        return
    print('%32s \x1B[4m[ logic from %s ]\x1B[0m' % ('', package))

def init_wads(package):
    if not package:
        gzd_dir = os.path.join(Utils.user_path(), "gzdoom")
        print_header(gzd_dir)
        os.makedirs(os.path.join(gzd_dir, "logic"), exist_ok=True) # in-dev logic files
        os.makedirs(os.path.join(gzd_dir, "tuning"), exist_ok=True) # in-dev tuning files
    else:
        print_header(package)

    logic = DoomLogic()

    files = logic_files(package)
    assert len(files) > 0, f'Package {package} contains no logic files'
    init_wad(logic, package, files)

    if 'GZAP_LOAD_ALL_TUNING' in os.environ:
        get_tuned_wad(logic.wad)

    return logic

def all_map_names(logic) -> Set[str]:
    return {map.map for map in logic.wad.all_maps()}

def all_categories(logic) -> FrozenSet[str]:
    return frozenset(unified_item_groups(logic).keys()) | frozenset(unified_location_groups(logic).keys())

def unified_item_map(logic):
    return logic.item_names_to_ids.copy()

def unified_item_groups(logic):
    return logic.item_categories_to_names.copy()

def unified_location_map(logic):
    return logic.location_names_to_ids.copy()

def unified_location_groups(logic):
    return logic.location_categories_to_names.copy()

from collections import Counter
from importlib import resources
import json, os, pickle, re

import Utils

from .DoomLogic import *

class WadDataLoader:
    wad: DoomWad

    def __enter__(self):
        return self

    def load_records(self, file):
        # print(f"Loading logic for {self.wad.name} from {file}")
        buf = ''
        for idx,line in enumerate(file.read_text().splitlines()):
            if not line.startswith("AP-") and not buf:
                continue

            if not line.endswith('}'):
                buf += line +  '\n'
                continue

            line = buf + line
            buf = ''

            try:
                [evt, payload] = line.split(" ", 1)
                payload = json.loads(payload)

                if evt == "AP-SCAN":
                    self.wad.flags = frozenset(payload['flags'])
                elif evt == "AP-MAP":
                    self.wad.new_map(payload)
                elif evt == "AP-ITEM":
                    self.wad.new_item(payload)
                elif evt == "AP-SCAN-DONE":
                    self.wad.finalize_scan(payload)
                elif evt == "AP-CHECK":
                    self.wad.tune_location(**payload)
                elif evt == "AP-SECRET":
                    self.wad.new_secret(payload)
                elif evt == "AP-KEY":
                    self.wad.new_key(**payload)
                else:
                    # AP-XON, AP-ACK, AP-STATUS, AP-CHAT, and other multiplayer-only messages
                    pass

            except Exception as e:
                raise ValueError(f"Error loading logic/tuning for {self.wad.name} on line {idx} of {file}:\n{line}") from e

    def print_stats(self) -> None:
        if "GZAP_DEBUG" not in os.environ:
            return

        nrof_maps = len(self.wad.all_maps())
        nrof_monsters = sum(map.monster_count for map in self.wad.all_maps())
        assert nrof_maps > 0,f"The logic for WAD {self.wad.name} defines no maps."

        print("\x1B[1m%32s: %2d maps, %4d monsters; %4d monsters/map\x1B[0m" % (
            self.wad.name, nrof_maps, nrof_monsters, nrof_monsters//nrof_maps))

        for sknum, skname in [(3, "UV")]: # [(1, "HNTR"), (2, "HMP"), (3, "UV")]:
            pool = self.wad.stats_pool(sknum)
            num_items = sum(pool.item_counts.values())
            num_p = sum(pool.progression_items().values())
            num_locs = len(pool.locations)
            num_secrets = len([loc for loc in pool.locations if loc.secret])
            print("%32s  %4d locs (%3d secret), %4d items (%4d progression)" % (
                skname, num_locs, num_secrets, num_items, num_p))

class WadLogicLoader(WadDataLoader):
    logic: DoomLogic
    wad: DoomWad

    def __init__(self, logic: DoomLogic, name: str, package: str):
        self.logic = logic
        self.wad = DoomWad(name, package)
        os.makedirs(os.path.join(Utils.user_path(), "gzdoom/cache"), exist_ok=True)

    def __exit__(self, err_type, err_value, err_stack):
        if err_type is not None:
            return False

        self.wad.finalize_all(self.logic)
        self.logic.add_wad(self.wad.name, self.wad)
        return True

    def load_logic(self, file):
        if self.logic_cache_valid(file):
            self.wad = self.load_cache()
        else:
            self.load_records(file)
            self.save_cache()

    def cache_path(self):
        gzd_dir = os.path.join(Utils.user_path(), "gzdoom")
        suffix = "ext" if self.wad.package is None else self.wad.package.replace('worlds.', '')
        return f'{gzd_dir}/cache/{self.wad.name}.{self.wad.package or "ext"}.pickle'

    def package_timestamp(self, package):
        apworld_path = re.sub(r'\.apworld.*', '.apworld', str(resources.files(package)))
        return os.path.getmtime(apworld_path)

    def logic_cache_valid(self, file):
        '''
        A logic cache is valid iff:
        - the cache file exists, and
        - the cache file is newer than gzdoom.apworld, and
        - the cache file is newer than the source logic.

        For the latter, that means the apworld containing it for logic files in
        apworlds, or the logic file on disk for external files.
        '''
        if not os.path.exists(self.cache_path()):
            return False

        if self.wad.package:
            ts = self.package_timestamp(self.wad.package)
        else:
            ts = os.path.getmtime(str(file))
        # If the core apworld is more recent, use that ts instead, since it may
        # have changed the internal definition of the DoomWad class.
        ts = max(ts, self.package_timestamp('worlds.gzdoom'))

        return os.path.getmtime(self.cache_path()) > ts

    def load_cache(self):
        with open(self.cache_path(), 'rb') as fd:
            # print(f'Leading cached logic from {self.cache_path()}')
            return pickle.load(fd)

    def save_cache(self):
        with open(self.cache_path(), 'wb') as fd:
            # print(f'Saving cached logic to {self.cache_path()}')
            pickle.dump(self.wad, fd)

class WadTuningLoader(WadDataLoader):
    def __init__(self, wad: DoomWad):
        self.wad = wad

    def __exit__(self, err_type, err_value, err_stack):
        return err_type is None

    def load_tuning(self, files):
        for file in files:
            self.load_records(file)

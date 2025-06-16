from collections import defaultdict
import json
import os
import pickle

import Utils

from .DoomLogic import *

class WadLogicLoader:
    logic: DoomLogic
    name: str
    apworld_mtime: int
    wad: DoomWad
    external: bool
    counters: defaultdict

    def __init__(self, logic: DoomLogic, name: str, apworld_mtime: int, external: bool):
        self.logic = logic
        self.name = name
        self.apworld_mtime = apworld_mtime
        self.wad = DoomWad(self.name)
        self.external = external
        self.counters = defaultdict(lambda: 0)
        os.makedirs(os.path.join(Utils.home_path(), "gzdoom/cache"), exist_ok=True)

    def __enter__(self):
        return self

    def __exit__(self, err_type, err_value, err_stack):
        if err_type is not None:
            return False

        self.wad.finalize_all(self.logic)
        self.logic.add_wad(self.name, self.wad)
        return True

    def cache_path(self, type):
        gzd_dir = os.path.join(Utils.home_path(), "gzdoom")
        if self.external:
            suffix = "ext.pickle"
        else:
            suffix = "pickle"
        return f'{gzd_dir}/cache/{self.name}.{type}.{suffix}'

    def tuning_cache_valid(self, files):
        '''
        A tuning cache file is valid iff:
        - the cache file exists, and
        - the cache is newer than the apworld (if there are internal tuning files), and
        - the cache is newer than the newest external tuning file (if there are external tuning files)
        '''
        if not os.path.exists(self.cache_path('tuning')):
            return False
        if len(files) == 0:
            return False

        newest = 0
        for file in files:
            if os.path.exists(str(file)):
                # External file
                newest = max(newest, os.path.getmtime(file))
            else:
                # Internal file
                newest = max(newest, self.apworld_mtime)

        return os.path.getmtime(self.cache_path('tuning')) > newest

    def logic_cache_valid(self, file):
        '''
        A logic cache is valid iff:
        - the cache file exists, and
        - the cache is newer than the apworld (if internal), and
        - the cache is newer than the logic file (if external)
        '''
        if not os.path.exists(self.cache_path('logic')):
            return False

        if os.path.exists(str(file)):
            # External file
            newest = os.path.getmtime(file)
        else:
            # Internal file
            newest = self.apworld_mtime

        return os.path.getmtime(self.cache_path('logic')) > newest

    def load_cache(self, type):
        with open(self.cache_path(type), 'rb') as fd:
          return pickle.load(fd)

    def save_cache(self, type):
        with open(self.cache_path(type), 'wb') as fd:
            # print(f'Saving cached logic to {self.cache_path('logic')}')
            pickle.dump(self.wad, fd)

    def load_records(self, file):
        # print(f"Loading logic for {self.name} from {file}")
        for idx,line in enumerate(file.read_text().splitlines()):
            if not line.startswith("AP-"):
                continue

            try:
                [evt, payload] = line.split(" ", 1)
                payload = json.loads(payload)
                self.counters[evt] += 1

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
                elif evt == "AP-KEY":
                    self.wad.new_key(**payload)
                else:
                    # AP-XON, AP-ACK, AP-STATUS, AP-CHAT, and other multiplayer-only messages
                    pass

            except Exception as e:
                raise ValueError(f"Error loading logic/tuning for {self.name} on line {idx} of {file}:\n{line}") from e

    def load_logic(self, file):
        self.load_records(file)
        self.save_cache('logic')

    def load_tuning(self, files):
        if len(files) == 0:
            # Empty tuning? Don't bother writing a cache.
            return
        for file in files:
            self.load_records(file)
        self.save_cache('tuning')

    def load_all(self, logic_file, tuning_files):
        if self.logic_cache_valid(logic_file):
            if self.tuning_cache_valid(tuning_files):
                # If all the caches are valid, just load the final one.
                # print(f'loading tuning cache for {self.name}')
                self.wad = self.load_cache('tuning')
                return
            else:
                # Logic cache is valid, tuning is not. Redo the tuning.
                # print(f'loading logic cache and redoing tuning {self.name}')
                self.wad = self.load_cache('logic')
                self.load_tuning(tuning_files)
                return
        else:
            # Logic cache is invalid. (In this case we don't care about the
            # tuning cache at all, since we need to redo it anyways as the
            # underlying logic has changed.)
            # print(f'cache miss for {self.name}')
            self.load_logic(logic_file)
            self.load_tuning(tuning_files)

    def print_stats(self, is_external: bool) -> None:
        if "GZAP_DEBUG" not in os.environ:
            return

        nrof_maps = len(self.wad.all_maps())
        nrof_monsters = sum(map.monster_count for map in self.wad.all_maps())
        assert nrof_maps > 0,f"The logic for WAD {self.name} defines no maps."

        print("\x1B[1m%32s: %2d maps, %4d monsters; %4d monsters/map\x1B[0m (I:%d S:%d T:%d)%s" % (
            self.name, nrof_maps, nrof_monsters, nrof_monsters//nrof_maps,
            self.counters.get("AP-ITEM", 0), self.counters.get("AP-SECRET", 0),
            self.counters.get("AP-CHECK", 0), is_external and " external" or ""))

        for sknum, skname in [(3, "UV")]: # [(1, "HNTR"), (2, "HMP"), (3, "UV")]:
            pool = self.wad.stats_pool(sknum)
            num_items = sum(pool.item_counts.values())
            num_p = sum(pool.progression_items().values())
            num_locs = len(pool.locations)
            num_secrets = len([loc for loc in pool.locations if loc.secret])
            print("%32s  %4d locs (%3d secret), %4d items (%4d progression)" % (
                skname, num_locs, num_secrets, num_items, num_p))

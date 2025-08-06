import fnmatch
from importlib import resources
import jinja2
import logging
import os
import random
from typing import Dict, FrozenSet, Set
import zipfile

from BaseClasses import CollectionState, Item, ItemClassification, Location, MultiWorld, Region, Tutorial, LocationProgressType
from worlds.AutoWorld import WebWorld, World
import worlds.LauncherComponents as LauncherComponents

from . import icons
from .Options import GZDoomOptions
from .model import init_wads
from .model.DoomItem import DoomItem
from .model.DoomLocation import DoomLocation
from .model.DoomWad import DoomWad

logger = logging.getLogger("gzDoom")

# Unfortunately this has to be done at load time, and there is no way to tell
# up front whether we're being loaded for something that needs the logic structures
# or something that doesn't. So we load them unconditionally and hope it doesn't
# slow things down too much as more wads are added.
init_wads(__package__)


def launch_client(*args) -> None:
    from .client.GZDoomClient import main
    # TODO: use launch() here once it's in main
    LauncherComponents.launch_subprocess(main, name="GZDoomClient", args=args)


LauncherComponents.icon_paths["gzdoom_icon"] = f"ap:{__name__}/icon.png"
LauncherComponents.components.append(
    LauncherComponents.Component(
        "GZDoom Client",
        func=launch_client,
        component_type=LauncherComponents.Type.CLIENT,
        icon="gzdoom_icon",
    )
)

class GZDoomLocation(Location):
    game: str = "gzDoom"
    doom_location: DoomLocation

    def __init__(self, world, loc: DoomLocation, region: Region) -> None:
        super().__init__(player=world.player, name=loc.name(), address=loc.id, parent=region)
        self.access_rule = loc.access_rule(world)
        self.doom_location = loc
        if loc.secret and not world.options.allow_secret_progress.value:
            self.progress_type = LocationProgressType.EXCLUDED
        else:
            self.progress_type = LocationProgressType.DEFAULT

    def flags(self) -> str:
        flags = []
        if self.item.classification & ItemClassification.progression:
            flags.append('AP_IS_PROGRESSION')
        if self.item.classification & ItemClassification.useful:
            flags.append('AP_IS_USEFUL')
        if self.item.classification & ItemClassification.trap:
            flags.append('AP_IS_TRAP')
        if self.doom_location.unreachable:
            flags.append('AP_IS_UNREACHABLE')
        if not flags:
            flags.append('AP_IS_FILLER')
        return '|'.join(flags)

class GZDoomItem(Item):
    game: str = "gzDoom"

    def __init__(self, item: DoomItem, player: int) -> None:
        super().__init__(name=item.name(), classification=item.classification(), code=item.id, player=player)

class GZDoomUTGlitchToken(Item):
    game: str = "gzDoom"
    TOKEN_NAME = "[UT Glitch Logic Token]"

    def __init__(self, player) -> None:
        super().__init__(name=self.TOKEN_NAME, classification=ItemClassification.progression, code=None, player=player)

class GZDoomWeb(WebWorld):
    tutorials = [Tutorial(
        "Multiworld Setup Guide",
        "A guide to setting up the gzDoom randomizer connected to an Archipelago Multiworld",
        "English",
        "setup_en.md",
        "setup/en",
        ["ToxicFrog"]
    )]
    theme = "dirt"


class GZDoomWorld(World):
    """
    gzDoom is an open-source enhanced port of the Doom engine, supporting Doom 1/2, Hexen, Heretic, and Strife, along
    with thousands of fan-made maps and mission packs and even a few commercial games like Hedon Bloodrite and Selaco.

    This randomizer comes with an automated WAD scanner that makes it easy to add support for new WADs.
    """
    game = "gzDoom"
    options_dataclass = GZDoomOptions
    options: GZDoomOptions
    topology_present = True
    web = GZDoomWeb()
    required_client_version = (0, 5, 1)
    included_item_categories = {}

    # Info fetched from gzDoom; contains item/location ID mappings etc.
    wad_logic: DoomWad
    location_count: int = 0

    # Used by the caller
    item_name_to_id: Dict[str, int] = model.unified_item_map()
    item_name_groups: Dict[str,FrozenSet[str]] = model.unified_item_groups()
    location_name_to_id: Dict[str, int] = model.unified_location_map()
    location_name_groups: Dict[str,FrozenSet[str]] = model.unified_location_groups()

    # Universal Tracker integration
    glitches_item_name: str = GZDoomUTGlitchToken.TOKEN_NAME
    ut_can_gen_without_yaml = True


    def __init__(self, multiworld: MultiWorld, player: int):
        self.location_count = 0
        super().__init__(multiworld, player)

    def create_item(self, name: str) -> GZDoomItem:
        if name == GZDoomUTGlitchToken.TOKEN_NAME:
            return GZDoomUTGlitchToken(self.player)

        item = self.wad_logic.items_by_name[name]
        return GZDoomItem(item, self.player)

    def any_glob_matches(self, globs: Set[str], name: str) -> bool:
        for glob in globs:
            if fnmatch.fnmatch(name, glob):
                return True
        return False

    def should_include_map(self, map: str) -> bool:
        if self.options.pretuning_mode:
            return True
        if self.any_glob_matches(self.options.excluded_levels.value, map):
            return False
        return self.any_glob_matches(self.options.included_levels.value or {"*"}, map)

    def is_starting_map(self, map: str) -> bool:
        return self.any_glob_matches(self.options.starting_levels.value, map)

    def setup_pretuning_mode(self):
        print("PRETUNING ENABLED - overriding most settings")
        self.options.start_with_all_maps.value = True
        self.options.included_levels.value = set()
        self.options.excluded_levels.value = set()
        self.options.level_order_bias.value = 0
        self.options.local_weapon_bias.value = 0
        self.options.carryover_weapon_bias.value = 0
        self.options.starting_levels.value = [map.map for map in self.maps]
        self.options.start_with_keys.value = False
        # self.options.full_persistence.value = False
        self.options.allow_respawn.value = True
        self.included_item_categories = {
            category: 1.0
            for category in model.all_categories()
        }

    def generate_early(self) -> None:
        ut_config = getattr(self.multiworld, "re_gen_passthrough", {}).get(self.game, None)
        if ut_config:
            print("Doing Universal Tracker worldgen with settings:", ut_config)
            for opt in ut_config:
                getattr(self.options, opt).value = ut_config[opt]

        wadlist = list(self.options.selected_wad.value)
        print(f"Permitted WADs: {wadlist}")

        self.wad_logic = model.get_wad(random.choice(wadlist))
        self.spawn_filter = self.options.spawn_filter.value
        skill_name = { 1: "easy", 2: "medium", 3: "hard" }[self.spawn_filter]
        print(f"Selected WAD: {self.wad_logic.name}")
        print(f"Selected spawns: {skill_name} ({self.options.spawn_filter.value})")

        self.included_item_categories = self.options.included_item_categories.value.copy()
        self.included_item_categories.update({ "key": 1, "weapon": 1, "token": 1 })

        self.maps = [
            map for map in self.wad_logic.maps.values()
            if self.should_include_map(map.map)
        ]

        # Set this up after building the map list but before building the location
        # list or item pool, since it sets options that should include all locations
        # and all items in the pool.
        # The list of maps already includes everything because should_include_map
        # has a special exception for pretuning mode.
        if self.options.pretuning_mode:
            self.setup_pretuning_mode()

        self.pool = self.wad_logic.fill_pool(self)

        if "GZAP_DEBUG" in os.environ:
            print("Selected maps:", sorted([map.map for map in self.maps]))
            print("Starting maps:", sorted([
                map.map for map in self.maps
                if self.is_starting_map(map.map)]))


    def create_regions(self) -> None:
        menu_region = Region("Menu", self.player, self.multiworld)
        self.multiworld.regions.append(menu_region)

        placed = set()

        for map in self.maps:
            if self.options.start_with_all_maps:
                item = self.create_item(map.automap_name())
                self.multiworld.push_precollected(item)
                self.pool.adjust_item(item.name, -1)

            if self.is_starting_map(map.map):
                for name in map.starting_items(self.options):
                    item = self.create_item(name)
                    self.multiworld.push_precollected(item)
                    self.pool.adjust_item(item.name, -1)

            region = Region(map.map, self.player, self.multiworld)
            self.multiworld.regions.append(region)
            rule = map.access_rule(self)
            menu_region.connect(
                connecting_region=region,
                name=f"{map.map}",
                rule=rule)
            for loc in self.pool.locations_in_map(map.map):
                assert loc.name() not in placed, f"Location {loc.name()} was already placed but we tried to place it again!"
                placed.add(loc.name())
                location = GZDoomLocation(self, loc, region)
                if self.options.pretuning_mode:
                    if loc.orig_item:
                        location.place_locked_item(self.create_item(loc.orig_item.name()))
                    elif loc.item:
                        location.place_locked_item(self.create_item(loc.item.name()))
                    else:
                        # Some synthetic locations, like secret sectors, don't have
                        # any items associated with them.
                        location.place_locked_item(self.create_item("Health"))
                elif loc.unreachable:
                    location.place_locked_item(self.create_item("Health"))
                elif loc.item:
                    location.place_locked_item(self.create_item(loc.item.name()))
                    self.pool.adjust_item(loc.item.name(), -1)
                else:
                    self.location_count += 1
                region.locations.append(location)


    def create_items(self) -> None:
        if self.options.pretuning_mode:
            # All locations have locked items in them, so there's no need to add
            # anything to the item pool.
            return

        slots_left = self.location_count
        main_items = self.pool.progression_items() | self.pool.useful_items()
        filler_items = self.pool.filler_items()

        for item,count in main_items.items():
            # if count > 0:
            #     print(f"Adding {count}× {item} to the pool.")
            for _ in range(max(count, 0)):
                self.multiworld.itempool.append(self.create_item(item))
                slots_left -= 1

        # compare slots_left to total count of filler_items, then scale filler_items
        # based on the difference.
        filler_count = sum(filler_items.values())
        if filler_count == 0:
            print("Warning: no filler items in pool!")
            return
        scale = slots_left/filler_count

        for item,count in filler_items.items():
            count = max(0, count)
            for _ in range(round(count * scale)):
                if slots_left <= 0:
                    break
                self.multiworld.itempool.append(self.create_item(item))
                slots_left -= 1

        # If rounding resulted in some empty slots, pick some extras from the pool
        # to fill them.
        for item in self.random.choices(list(filler_items.keys()), k=slots_left, weights=filler_items.values()):
            self.multiworld.itempool.append(self.create_item(item))
            slots_left -= 1

    def set_rules(self):
        # All region and location access rules were defined in create_regions, so we just need the
        # overall victory condition here.
        self.multiworld.completion_condition[self.player] = lambda state: self.options.win_conditions.check_win(self, state)

    def all_placed_item_names(self):
        """
        Returns the names of all items that exist in the generated world.

        In practice this means everything in your starting inventory + everything
        placed at at least one location.
        """
        return {
            loc.item.name for loc in self.multiworld.get_locations(self.player)
            if loc.item
        } | {
            item.name for item in self.multiworld.precollected_items[self.player]
        }

    def keys_in_pool(self):
        return {
            key
            for mapinfo in self.maps
            for key in self.wad_logic.keys_for_map(mapinfo.map)
        }

    def key_in_world(self, keyname):
        return keyname in {key.fqin() for key in self.keys_in_pool()}

    def fill_slot_data(self):
        return self.options.as_dict(
            'level_order_bias', 'local_weapon_bias', 'carryover_weapon_bias',
            'spawn_filter', 'included_item_categories') | {
                'selected_wad': [self.wad_logic.name]
            }

    # Called by UT on connection. In UT mode all configuration will come from
    # slot_data rather than via the YAML.
    @staticmethod
    def interpret_slot_data(slot_data):
        print("interpret_slot_data", slot_data)
        return slot_data

    def generate_output(self, path):
        def progression(name: str) -> bool:
            # print("is_progression?", id, name)
            loc = self.multiworld.get_location(name, self.player)
            if loc.item and (loc.item.classification & ItemClassification.progression != 0):
                return "true"
            else:
                return "false"

        # The nice thing about drawing item and location IDs from the same pool
        # is that we know each ID can only ever be one or the other, so this is
        # safe.
        def id(name: str) -> int:
            if name in self.location_name_to_id:
                return self.location_name_to_id[name]
            else:
                return self.item_name_to_id[name]

        def item_at(name: str) -> str:
            loc = self.get_location(name)
            if loc.item and loc.item.name in self.wad_logic.items_by_name:
                return self.wad_logic.items_by_name[loc.item.name]
            return None

        def item_type_at(name: str) -> str:
            loc = self.get_location(name)
            if loc.item and loc.item.name in self.wad_logic.items_by_name:
                return self.wad_logic.items_by_name[loc.item.name].typename
            return (icons.guess_icon(self.wad_logic, loc.item.game, loc.item.name)
                or f"NONE:{loc.item.game}:{loc.item.name}")

        def item_name_at(name: str) -> str:
            loc = self.get_location(name)
            if loc.item:
                return escape(loc.item.name)
            return ""

        def flags_at(loc: DoomLocation) -> str:
            return self.get_location(loc.name()).flags()

        def locations(map):
            return self.pool.locations_in_map(map)

        def escape(name: str) -> str:
            return name.replace('\\', '\\\\').replace('"', '\\"')

        mod_version = resources.files(__package__).joinpath('VERSION').read_text().strip()

        data = {
            "singleplayer": self.multiworld.players == 1,
            "pretuning": self.options.pretuning_mode.value,
            "seed": self.multiworld.seed_name,
            "mod_version": mod_version,
            "player": self.multiworld.player_name[self.player],
            "spawn_filter": self.spawn_filter,
            "persistence": self.options.full_persistence.value,
            "respawn": self.options.allow_respawn.value,
            "wad": self.wad_logic.name,
            "keys": self.keys_in_pool(),
            "maps": self.maps,
            "items": self.pool.all_pool_items(),
            "starting_items": [
                item.code for item in self.multiworld.precollected_items[self.player]
            ],
            "singleplayer_items": {
                loc.address: loc.item.code
                for loc in self.multiworld.get_locations(self.player)
                if loc.item
            },
            "progression": progression,
            "locations": locations,
            "id": id,
            "item_at": item_at,
            "item_type_at": item_type_at,
            "item_name_at": item_name_at,
            "flags_at": flags_at,
            "escape": escape,
            "win_conditions": self.options.win_conditions.template_values(self),
            "generate_mapinfo": (not self.options.pretuning_mode) or self.options.full_persistence,
        }

        env = jinja2.Environment(
            loader=jinja2.PackageLoader(__package__),
            trim_blocks=True,
            lstrip_blocks=True)

        pk3_path = os.path.join(
            path,
            f"{self.multiworld.get_out_file_name_base(self.player)}.{self.wad_logic.name.replace(' ', '_')}.pk3")

        with zipfile.ZipFile(pk3_path, mode="w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zip:
            zip.writestr("ZSCRIPT", env.get_template("zscript.jinja").render(**data))
            zip.writestr("MAPINFO", env.get_template("mapinfo.jinja").render(**data))
            zip.writestr("VERSION", mod_version)

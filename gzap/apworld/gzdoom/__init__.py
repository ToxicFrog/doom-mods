import importlib.resources as resources
import logging
import os
import random
from typing import Dict

import jinja2
from BaseClasses import CollectionState, Item, ItemClassification, Location, MultiWorld, Region, Tutorial
from worlds.AutoWorld import WebWorld, World
import worlds.LauncherComponents as LauncherComponents

from .Options import GZDoomOptions
from .model import DoomItem, DoomLocation, DoomWad, init_wads, get_wad

# TODO: is there a way we can tell when we're being loaded to run the client,
# and skip initializing the WAD logic, which is relatively expensive?
logger = logging.getLogger("gzDoom")
init_wads(__package__)


def launch_client(*args) -> None:
    from .client.GZDoomClient import main
    # TODO: use launch() here once it's in main
    LauncherComponents.launch_subprocess(main, name="GZDoomClient", args=args)


LauncherComponents.components.append(
    LauncherComponents.Component(
        "GZDoom Client",
        func=launch_client,
        component_type=LauncherComponents.Type.CLIENT
    )
)


class GZDoomLocation(Location):
    game: str = "gzDoom"

    def __init__(self, player: int, loc: DoomLocation, region: Region) -> None:
        super().__init__(player=player, name=loc.name(), address=loc.id, parent=region)
        self.access_rule = loc.access_rule(player)


class GZDoomItem(Item):
    game: str = "gzDoom"

    def __init__(self, item: DoomItem, player: int) -> None:
        super().__init__(name=item.name(), classification=item.classification(), code=item.id, player=player)


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

    # Info fetched from gzDoom; contains item/location ID mappings etc.
    wad_logic: DoomWad
    location_count: int = 0

    # Used by the caller
    item_name_to_id: Dict[str, int] = model.unified_item_map()
    location_name_to_id: Dict[str, int] = model.unified_location_map()

    def __init__(self, multiworld: MultiWorld, player: int):
        self.location_count = 0
        super().__init__(multiworld, player)

    def create_item(self, name: str) -> GZDoomItem:
        item = self.wad_logic.items_by_name[name]
        return GZDoomItem(item, self.player)

    def generate_early(self) -> None:
        # for k in self.item_name_to_id:
        #     print(self.item_name_to_id[k], k)
        # for k in self.location_name_to_id:
        #     print(self.location_name_to_id[k], k)
        wadlist = list(self.options.selected_wad.value)
        print(f"Permitted WADs: {wadlist}")
        self.wad_logic = model.get_wad(random.choice(wadlist))
        print(f"Selected WAD: {self.wad_logic.name}")

    def create_regions(self) -> None:
        menu_region = Region("Menu", self.player, self.multiworld)
        self.multiworld.regions.append(menu_region)

        placed = set()

        for map in self.wad_logic.maps.values():
            # print("Region:", map.map)
            if map.map not in self.options.included_levels:
                continue

            if self.options.start_with_all_maps:
                item = self.wad_logic.item(map.automap_name())
                self.multiworld.push_precollected(GZDoomItem(item, self.player))
                item.count -= 1

            if map.map in self.options.starting_levels:
                for name in map.starting_items():
                    item = self.wad_logic.item(name)
                    self.multiworld.push_precollected(GZDoomItem(item, self.player))
                    item.count -= 1

            region = Region(map.map, self.player, self.multiworld)
            self.multiworld.regions.append(region)
            menu_region.connect(
                connecting_region=region,
                name=f"{map.map}",
                rule=map.access_rule(self.player))
            for loc in map.locations:
                # print("  Location:", loc.name(), loc)
                assert loc.name() not in placed
                placed.add(loc.name())
                location = GZDoomLocation(self.player, loc, region)
                region.locations.append(location)
                if loc.item:
                    location.place_locked_item(GZDoomItem(loc.item, self.player))
                    loc.item.count -= 1
                else:
                    self.location_count += 1


    def create_items(self) -> None:
        slots_left = self.location_count
        main_items = self.wad_logic.progression_items() + self.wad_logic.useful_items()
        filler_items = self.wad_logic.filler_items()

        for item in main_items:
            if item.map not in self.options.included_levels:
                continue
            print("  Item:", item)
            for _ in range(max(item.count, 0)):
                self.multiworld.itempool.append(GZDoomItem(item, self.player))
                slots_left -= 1

        # compare slots_left to total count of filler_items, then scale filler_items
        # based on the difference.
        filler_count = 0
        for item in filler_items:
            filler_count += item.count
        scale = slots_left/filler_count

        for item in filler_items:
            for _ in range(round(item.count * scale)):
                if slots_left <= 0:
                    break
                self.multiworld.itempool.append(GZDoomItem(item, self.player))
                slots_left -= 1

        # Hack hack hack -- if rounding resulted having some empty slots, fill them
        # with whatever's first in filler_items
        while slots_left > 0:
            self.multiworld.itempool.append(GZDoomItem(filler_items.copy().pop(), self.player))
            slots_left -= 1

    def mission_complete(self, state: CollectionState) -> bool:
        for map in self.wad_logic.maps.values():
            if map.map not in self.options.included_levels:
                continue
            if not state.has(map.clear_token_name(), self.player):
                return False
        return True

    def set_rules(self):
        # All region and location access rules were defined in create_regions, so we just need the
        # overall victory condition here.
        self.multiworld.completion_condition[self.player] = lambda state: self.mission_complete(state)

    def generate_output(self, path):
        def progression(id: int) -> bool:
            # get location from ID
            name = self.location_id_to_name[id]
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

        data = {
            "singleplayer": self.multiworld.players == 1,
            "seed": self.multiworld.seed_name,
            "player": self.multiworld.player_name[self.player],
            "skill": self.wad_logic.skill,
            "maps": [
                map for map in self.wad_logic.maps.values()
                if map.map in self.options.included_levels
            ],
            "items": [
              item for item in self.wad_logic.items()
            ],
            "starting_items": [
              item.code for item in self.multiworld.precollected_items[self.player]
            ],
            "singleplayer_items": {
                loc.address: loc.item.code
                for loc in self.multiworld.get_locations(self.player)
                if loc.item
            },
            "progression": progression,
            "id": id
        }

        env = jinja2.Environment(
            loader=jinja2.PackageLoader(__package__),
            trim_blocks=True,
            lstrip_blocks=True)
        with open(os.path.join(path, "zscript.txt"), "w") as lump:
            template = env.get_template("zscript.jinja")
            lump.write(template.render(**data))
            print(template.render(**data))

        with open(os.path.join(path, "MAPINFO"), "w") as lump:
            template = env.get_template("mapinfo.jinja")
            lump.write(template.render(**data))
            # print(template.render(**data))

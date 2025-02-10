import logging
import os
import typing
from typing import Any, Dict, List

import settings
import jinja2
from BaseClasses import CollectionState, Item, ItemClassification, Location, MultiWorld, Region, Tutorial
from worlds.AutoWorld import WebWorld, World
# from . import Items, Locations, Maps, Regions, Rules
from .Options import GZDoomOptions
from .WadInfo import WadInfo, WadItem, WadLocation, get_wadinfo, get_wadinfo_path

logger = logging.getLogger("gzDoom")


class GZDoomLocation(Location):
    game: str = "gzDoom"
    wadlocation: WadLocation

    def __init__(self, player: int, loc: WadLocation, region: Region) -> None:
        super().__init__(player=player, name=loc.name, address=loc.id, parent=region)
        self.access_rule = loc.access_rule(player)
        self.wadlocation = loc

class GZDoomItem(Item):
    game: str = "gzDoom"
    waditem: WadItem

    def __init__(self, item: WadItem, player: int) -> None:
        super().__init__(name=item.name, classification=item.classification(), code=item.id, player=player)
        self.waditem = item


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


class GZDoomSettings(settings.Group):
    class WadInfoFile(settings.UserFilePath):
        """File name of the WAD info dump produced by gzap.pk3's scan command"""
        # TODO: figure out what the hell copy_to actually does
        copy_to = "wadinfo.txt"
        description = "WADInfo file"

    wad_info_file: WadInfoFile = WadInfoFile(WadInfoFile.copy_to)



    # Items can be grouped using their names to allow easy checking if any item
    # from that group has been collected. Group names can also be used for !hint
    item_name_groups = {
        "weapons": {"sword", "lance"},
    }

class GZDoomWorld(World):
    """
    gzDoom is an open-source enhanced port of the Doom engine, supporting Doom 1/2, Hexen, Heretic, and Strife, along
    with thousands of fan-made maps and mission packs and even a few commercial games like Hedon Bloodrite and Selaco.

    This randomizer attempts to support all vanilla-compatible or limit-removing Doom 1/2 megaWADs. It may also work
    with non-Doom-based games like Heretic and Bloodrite.
    """
    game = "gzDoom"
    options_dataclass = GZDoomOptions
    options: GZDoomOptions
    settings: typing.ClassVar[GZDoomSettings]
    topology_present = True
    web = GZDoomWeb()
    required_client_version = (0, 3, 9)

    # Info fetched from gzDoom; contains item/location ID mappings etc.
    wadinfo: WadInfo
    location_count: int = 0

    # Used by the caller
    item_name_to_id: Dict[str, int] = {}
    location_name_to_id: Dict[str, int] = {}
    location_id_to_name: Dict[int, str]

    def __init__(self, multiworld: MultiWorld, player: int):
        self.included_episodes = [1, 1, 1, 0]
        self.location_count = 0

        super().__init__(multiworld, player)

    @classmethod
    def stage_assert_generate(cls, multiworld: MultiWorld):
        wadinfo_path = get_wadinfo_path()
        if not os.path.exists(wadinfo_path):
            raise FileNotFoundError(wadinfo_path)

    def create_item(self, name: str) -> GZDoomItem:
        item = self.wadinfo.items_by_name[name]
        return GZDoomItem(item, self.player)

    def generate_early(self) -> None:
        self.wadinfo = get_wadinfo()
        self.item_name_to_id = {
            item.name: item.id
            for item in self.wadinfo.items_by_name.values()
        }
        self.location_name_to_id = {
            loc.name: loc.id
            for loc in self.wadinfo.locations_by_name.values()
        }
        self.location_id_to_name = {
            loc.id: loc.name
            for loc in self.wadinfo.locations_by_name.values()
        }

    def create_regions(self) -> None:
        menu_region = Region("Menu", self.player, self.multiworld)
        self.multiworld.regions.append(menu_region)

        for map in self.wadinfo.maps.values():
            region = Region(map.map, self.player, self.multiworld)
            self.multiworld.regions.append(region)
            menu_region.connect(
                connecting_region=region,
                name=f"{map.map}",
                rule=map.access_rule(self.player))
            for loc in map.locations:
                location = GZDoomLocation(self.player, loc, region)
                region.locations.append(location)
                if loc.item:
                    location.place_locked_item(GZDoomItem(loc.item, self.player))
                    loc.item.count -= 1
                else:
                    self.location_count += 1


    def create_items(self) -> None:
        for item in self.wadinfo.starting_items():
          self.multiworld.push_precollected(GZDoomItem(item, self.player))
          item.count -= 1

        slots_left = self.location_count
        main_items = set([
            i for i in self.wadinfo.items_by_name.values()
            if i.classification() != ItemClassification.filler
        ])

        for item in main_items:
            for _ in range(item.count):
                self.multiworld.itempool.append(GZDoomItem(item, self.player))
                slots_left -= 1

        # compare slots_left to total count of filler_items, then scale filler_items
        # based on the difference.
        filler_items = set([
            i for i in self.wadinfo.items_by_name.values()
            if i.classification() == ItemClassification.filler
        ])
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
        for map in self.wadinfo.maps.values():
            if not state.has(map.clear_token_name(), self.player):
                return False
        return True

    def set_rules(self):
        # All region and location access rules were defined in create_regions, so we just need the
        # overall victory condition here.
        self.multiworld.completion_condition[self.player] = lambda state: self.mission_complete(state)

    def generate_output_old(self, path):
        print("# GZAP output generation", path)
        print("## Metadata")
        print("seed:", self.multiworld.seed_name)
        print("player:", self.player, self.multiworld.player_name[self.player])
        print("## Item table")
        for item in self.wadinfo.items_by_name.values():
            print("item:", item.id, item.typename, item.name, item.category)
        print("## Location table")
        for loc in self.wadinfo.locations_by_name.values():
            print("location", loc.id, loc.name, loc.keyset, loc.pos)
            aploc = self.multiworld.get_location(loc.name, self.player)
            if aploc.item:
                print("  ->  ", aploc.item.code, aploc.item.name)

    def generate_output(self, path):
        def progression(id):
            # get location from ID
            name = self.location_id_to_name[id]
            loc = self.multiworld.get_location(name, self.player)
            if loc.item and (loc.item.classification & ItemClassification.progression != 0):
                return "true"
            else:
                return "false"

        data = {
            "singleplayer": self.multiworld.players == 1,
            "seed": self.multiworld.seed_name,
            "player": self.multiworld.player_name[self.player],
            "skill": self.wadinfo.skill,
            "maps": [
              map for map in self.wadinfo.maps.values()
            ],
            "items": [
              item for item in self.wadinfo.items_by_name.values()
            ],
            "starting_items": [
              item.code for item in self.multiworld.precollected_items[self.player]
            ],
            "singleplayer_items": {
                loc.address: loc.item.code
                for loc in self.multiworld.get_locations(self.player)
                if loc.item
            },
            "progression": progression
        }

        env = jinja2.Environment(
            loader=jinja2.PackageLoader("worlds.gzdoom"),
            trim_blocks=True,
            lstrip_blocks=True)
        with open(os.path.join(path, "zscript.txt"), "w") as lump:
            template = env.get_template("zscript.jinja")
            lump.write(template.render(**data))
            print(template.render(**data))

        with open(os.path.join(path, "MAPINFO"), "w") as lump:
            template = env.get_template("mapinfo.jinja")
            lump.write(template.render(**data))
            print(template.render(**data))

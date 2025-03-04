import jinja2
import logging
import os
import random
from typing import Dict
import zipfile

from BaseClasses import CollectionState, Item, ItemClassification, Location, MultiWorld, Region, Tutorial, LocationProgressType
from worlds.AutoWorld import WebWorld, World
import worlds.LauncherComponents as LauncherComponents

from .Options import GZDoomOptions
from .model import DoomItem, DoomLocation, DoomWad, init_wads, get_wad

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


LauncherComponents.components.append(
    LauncherComponents.Component(
        "GZDoom Client",
        func=launch_client,
        component_type=LauncherComponents.Type.CLIENT
    )
)


class GZDoomLocation(Location):
    game: str = "gzDoom"

    def __init__(self, options, player: int, loc: DoomLocation, region: Region) -> None:
        super().__init__(player=player, name=loc.name(), address=loc.id, parent=region)
        self.access_rule = loc.access_rule(player)
        if loc.secret and not options.allow_secret_progress.value:
            self.progress_type = LocationProgressType.EXCLUDED
        else:
            self.progress_type = LocationProgressType.DEFAULT


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

    # How many of each item we have left; stored outside the item so that we
    # don't have to mutate the DoomItem to keep track of it, which would have
    # bad side effects if multipler players are using this apworld in the same
    # generation pass.
    item_counts: Dict[str, int]

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
        print(f"Selected skill: {self.options.skill.value}")
        self.maps = [
            map for map in self.wad_logic.maps.values()
            if self.should_include_map(map.map)
        ]
        self.item_counts = {
            item.name(): item.get_count(self.options, self.maps)
            for item in self.wad_logic.items(self.options.skill.value)
        }

    def create_regions(self) -> None:
        menu_region = Region("Menu", self.player, self.multiworld)
        self.multiworld.regions.append(menu_region)

        placed = set()

        for map in self.wad_logic.maps.values():
            # print("Region:", map.map)
            if not self.should_include_map(map.map):
                continue

            if self.options.start_with_all_maps:
                item = self.wad_logic.item(map.automap_name())
                self.multiworld.push_precollected(GZDoomItem(item, self.player))
                self.item_counts[item.name()] -= 1

            if map.map in self.options.starting_levels:
                for name in map.starting_items():
                    item = self.wad_logic.item(name)
                    self.multiworld.push_precollected(GZDoomItem(item, self.player))
                    self.item_counts[item.name()] -= 1

            region = Region(map.map, self.player, self.multiworld)
            self.multiworld.regions.append(region)
            menu_region.connect(
                connecting_region=region,
                name=f"{map.map}",
                rule=map.access_rule(
                    self.player,
                    need_priors=self.options.level_order_bias.value / 100,
                    require_weapons=(map.map not in self.options.starting_levels)))
            for loc in map.all_locations(self.options.skill.value):
                # print("  Location:", loc.name(), loc)
                assert loc.name() not in placed
                placed.add(loc.name())
                location = GZDoomLocation(self.options, self.player, loc, region)
                region.locations.append(location)
                if loc.unreachable:
                    # TODO: put a BasicHealthBonus here or something
                    # We want SOMETHING here so that if the player manages to
                    # reach it after all, we emit a check message for it clearing
                    # the unreachable bit.
                    location.place_locked_item(GZDoomItem(
                        self.wad_logic.item("Backpack"), self.player))
                elif loc.item:
                    location.place_locked_item(GZDoomItem(loc.item, self.player))
                    self.item_counts[loc.item.name()] -= 1
                else:
                    self.location_count += 1


    def create_items(self) -> None:
        slots_left = self.location_count
        main_items = (self.wad_logic.progression_items(self.options.skill.value)
                      + self.wad_logic.useful_items(self.options.skill.value))
        filler_items = self.wad_logic.filler_items(self.options.skill.value)

        for item in main_items:
            if item.map and not self.should_include_map(item.map):
                continue
            # print("  Item:", item, item.count)
            for _ in range(max(self.item_counts[item.name()], 0)):
                self.multiworld.itempool.append(GZDoomItem(item, self.player))
                slots_left -= 1

        # compare slots_left to total count of filler_items, then scale filler_items
        # based on the difference.
        filler_count = 0
        for item in filler_items:
            filler_count += self.item_counts[item.name()]
        scale = slots_left/filler_count

        for item in filler_items:
            for _ in range(round(self.item_counts[item.name()] * scale)):
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
        for map in self.maps:
            if not state.has(map.clear_token_name(), self.player):
                return False
        return True

    def set_rules(self):
        # All region and location access rules were defined in create_regions, so we just need the
        # overall victory condition here.
        self.multiworld.completion_condition[self.player] = lambda state: self.mission_complete(state)

    def should_include_map(self, map: str) -> bool:
        if map in self.options.excluded_levels:
            return False
        if self.options.included_levels.value and map not in self.options.included_levels:
            return False
        return True

    def generate_output(self, path):
        def progression(id: int) -> bool:
            # get location from ID
            name = self.location_id_to_name[id]
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

        data = {
            "singleplayer": self.multiworld.players == 1,
            "seed": self.multiworld.seed_name,
            "player": self.multiworld.player_name[self.player],
            "skill": self.options.skill.value,
            "persistence": self.options.full_persistence.value,
            "respawn": self.options.allow_respawn.value,
            "wad": self.wad_logic.name,
            "maps": self.maps,
            "items": [
              item for item in self.wad_logic.items(self.options.skill.value)
              if (not item.map or self.should_include_map(item.map))
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
            "id": id,
        }

        env = jinja2.Environment(
            loader=jinja2.PackageLoader(__package__),
            trim_blocks=True,
            lstrip_blocks=True)

        pk3_path = os.path.join(path, f"{self.multiworld.get_out_file_name_base(self.player)}.pk3")

        with zipfile.ZipFile(pk3_path, mode="w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zip:
            zip.writestr("ZSCRIPT", env.get_template("zscript.jinja").render(**data))
            zip.writestr("MAPINFO", env.get_template("mapinfo.jinja").render(**data))

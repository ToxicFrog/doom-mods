"""
Top-level class for holding the actual game logic.

In order for datapack generation in multiworld games to work right, we need to
incorporate the information for *all wads that we know about*. So this class
holds per-wad information association locations with maps and grouping the maps
together into wads, as well as cross-wad information about all the items and
locations we are aware of across all supported wads, used for populating the
datapack.

(We can't selectively load this based on randomizer configuration because, at
present, the datapack is generated as soon as the apworld is loaded, before the
World subclass is even instantiated; well before we have access to the yaml.)
"""

from dataclasses import dataclass, field
from itertools import chain, combinations
from typing import Dict, List, Set

from .DoomItem import DoomItem
from .DoomLocation import DoomLocation
from .DoomWad import DoomWad

@dataclass
class DoomLogic:
    last_id: int = 0
    wad: DoomWad = None
    item_names_to_ids: Dict[str,int] = field(default_factory=dict)
    item_categories_to_names: Dict[str, Set[str]] = field(default_factory=dict)
    location_names_to_ids: Dict[str,int] = field(default_factory=dict)
    location_categories_to_names: Dict[str, Set[str]] = field(default_factory=dict)

    def next_id(self) -> int:
        self.last_id += 1
        return self.last_id

    # def items(self) -> List[DoomItem]:
    #     return self.items.values()

    # def locations(self) -> List[DoomLocation]:
    #     return self.locations.values()

    def add_wad(self, name: str, wad: DoomWad):
        assert self.wad is None
        self.wad = wad

    def all_subcategory_strings(self, cats):
        cats = list(cats)
        return (
            '-'.join(sorted(subcats))
            for subcats in chain.from_iterable(
                combinations(cats, i) for i in range(1, len(cats)+1))
        )

    def register_item(self, item: DoomItem) -> int:
        """
        Register an item and return its assigned ID.

        If there's an existing item with that name, returns the already-allocated
        ID. If not, allocates and returns a new one.

        Note that item names don't have to have the same backing WadItem across
        different wads, so it is the job of individual DoomWads to deal with name
        collisions for different items.
        """
        name: str = item.name()
        if name not in self.item_names_to_ids:
            self.item_names_to_ids[name] = self.next_id()
        item.id = self.item_names_to_ids[name]
        for cat in self.all_subcategory_strings(item.categories):
            self.item_categories_to_names.setdefault(cat, set()).add(name)
        return item.id

    def register_location(self, loc: DoomLocation):
        name: str = loc.name()
        if name not in self.location_names_to_ids:
            self.location_names_to_ids[name] = self.next_id()
        loc.id = self.location_names_to_ids[name]
        for cat in self.all_subcategory_strings(loc.categories):
            self.location_categories_to_names.setdefault(cat, set()).add(name)
        return loc.id

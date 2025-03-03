import re
from typing import Tuple

class GZDoomHint:
    item: int
    player: int
    location: int

    def __init__(self, item, finding_player, location, **json):
        self.item = item
        self.player = finding_player
        self.location = location

    def hint_info(self, ctx) -> Tuple[str, str, str, str]:
        """
        Returns [map name, item name, finding player, location].

        Map name may be None if it's not a scoped item.
        """
        (map_name, item_name) = self.item_info(ctx)
        return (
            map_name, item_name,
            self.player_name(ctx.jsontotextparser),
            self.location_name(ctx.jsontotextparser)
        )

    def item_info(self, ctx) -> Tuple[str, str]:
        """
        Returns the [map name, item name] of the item.

        Map name may be None if it's not a scoped item.
        """
        item_name = ctx.item_names.lookup_in_slot(self.item, ctx.slot)
        match = re.match(r"^(.+) \((.*)\)$", item_name)
        if match:
            return (match.group(2), match.group(1))
        else:
            return (None, item_name)

    def player_name(self, parser):
        return parser.handle_node({
            "type": "player_id",
            "text": self.player,
        })

    def location_name(self, parser):
        return parser.handle_node({
            "type": "location_id",
            "text": self.location,
            "player": self.player,
        })


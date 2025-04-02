"""
Tracking of hints and peeks in the client.

AP itself doesn't really have this distinction -- it's all hints. We send them
to gzDoom differently, so we use the same class for both but the methods draw
a distinction between whether it's a hint (one of our items in someone else's
world) or a peek (someone else's item in our world). A Hint can actually be both --
one of our items in our world -- in which case it's sent twice, once with HINT
and once with PEEK.
"""

import re
from typing import Tuple

class GZDoomHint:
    item: int
    finding_player: int
    receiving_player: int
    location: int

    def __init__(self, item, finding_player, receiving_player, location, **json):
        self.item = item
        self.finding_player = finding_player
        self.receiving_player = receiving_player
        self.location = location

    def is_relevant(self, ctx) -> bool:
        return self.is_hint(ctx) or self.is_peek(ctx)

    def is_hint(self, ctx) -> bool:
        return ctx.slot_concerns_self(self.receiving_player)

    def is_peek(self, ctx) -> bool:
        return ctx.slot_concerns_self(self.finding_player)

    def hint_info(self, ctx) -> Tuple[str, str, str, str]:
        """
        Returns [map name, item name, finding player, location].

        Map name may be None if it's not a scoped item.
        """
        (map_name, item_name) = self.item_info(ctx)
        return (
            map_name, item_name,
            self.player_name(ctx.jsontotextparser, self.finding_player),
            self.location_name(ctx.jsontotextparser),
        )

    def peek_info(self, ctx) -> Tuple[str, str, str, str]:
        """
        Returns [map name, location name, receiving player, item].
        """
        (map_name, location_name) = self.location_info(ctx)
        return (
            map_name, location_name,
            self.player_name(ctx.jsontotextparser, self.receiving_player),
            self.item_name(ctx.jsontotextparser),
        )

    def item_info(self, ctx) -> Tuple[str, str]:
        """
        Returns the [map name, item name] of the item.

        Map name may be None if it's not a scoped item.
        """
        item_name = ctx.item_names.lookup_in_slot(self.item, ctx.slot)
        match = re.match(r"^.+ \((.*)\)$", item_name)
        if match:
            return (match.group(1), item_name)
        else:
            return (None, item_name)

    def location_info(self, ctx) -> Tuple[str, str]:
        """
        Returns the [map name, location name] for this hint.
        """
        loc_name = ctx.location_names.lookup_in_slot(self.location, ctx.slot)
        return (loc_name.split(" - ", 1)[0], loc_name)

    def player_name(self, parser, id):
        return parser.handle_node({
            "type": "player_id",
            "text": id,
        })

    def item_name(self, parser):
        return parser.handle_node({
            "type": "item_id",
            "text": self.item,
            "player": self.receiving_player,
        })

    def location_name(self, parser):
        return parser.handle_node({
            "type": "location_id",
            "text": self.location,
            "player": self.finding_player,
        })


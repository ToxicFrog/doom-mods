"""
Tracking of hints and peeks in the client.

AP itself doesn't really have this distinction -- it's all hints. We send them
to UZDoom differently, so we use the same class for both but the methods draw
a distinction between whether it's a hint (one of our items in someone else's
world) or a peek (someone else's item in our world). A Hint can actually be both --
one of our items in our world -- in which case it's sent twice, once with HINT
and once with PEEK.
"""

import re
from typing import Tuple

class UZDoomHint:
    item: int
    finding_player: int
    receiving_player: int
    location: int
    item_flags: int

    def __init__(self, item, finding_player, receiving_player, location, item_flags, **json):
        self.item = item
        self.finding_player = finding_player
        self.receiving_player = receiving_player
        self.location = location
        self.item_flags = item_flags

    def __str__(self):
        return f'Hint(item={self.item}, finder={self.finding_player}, receiver={self.receiving_player}, loc={self.location})'

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
            self.player_name(ctx, self.finding_player),
            self.location_name(ctx),
        )

    def peek_info(self, ctx) -> Tuple[str, int, str, str]:
        """
        Returns [map name, location id, receiving player, item].
        """
        (map_name, location_name) = self.location_info(ctx)
        return (
            map_name, self.location,
            self.player_name(ctx, self.receiving_player),
            self.item_name(ctx),
        )

    def item_info(self, ctx) -> Tuple[str, str]:
        """
        Returns the [map name, item name] of the item.

        Map name may be None if it's not a scoped item. Only called for hints,
        i.e. information about items that belong to us.
        """
        item_name = ctx.item_names.lookup_in_slot(self.item, ctx.slot)
        item = ctx.wad_logic.item(item_name)
        assert item_name == item.name(), f"Item name mismatch: {item_name} from AP doesn't match {item.name()} from WAD"
        return (item.map, item_name)

    def is_valid(self, ctx):
        if self.is_hint(ctx) and ctx.item_names.lookup_in_slot(self.item, ctx.slot) not in ctx.wad_logic.items_by_name:
            # A hint contains information about an item for us, in someone else's world.
            # This means that the item must be one we can identify.
            print('Not in item name table:', ctx.item_names.lookup_in_slot(self.item, ctx.slot))
            return False

        if self.is_peek(ctx) and ctx.location_names.lookup_in_slot(self.location, ctx.slot) not in ctx.wad_logic.locations_by_name:
            # A peek contains information about an item for someone else, in a location
            # in our world. So we need to know the location.
            print('Not in location name table:', ctx.location_names.lookup_in_slot(self.location, ctx.slot))
            return False

        return True

    def location_info(self, ctx) -> Tuple[str, str]:
        """
        Returns the [map name, location name] for this hint.

        Only called for peeks, i.e. information about locations that belong
        to us.
        """
        loc_name = ctx.location_names.lookup_in_slot(self.location, ctx.slot)
        loc = ctx.wad_logic.location_named(loc_name)
        assert loc_name == loc.name(), f"Location name mismatch: {loc_name} from AP doesn't match {loc.name()} from WAD"
        return (loc.pos.map, loc_name)

    def player_name(self, ctx, id):
        return ctx.jsontozdoomtextparser.handle_node({
            "type": "player_id",
            "text": id,
        })

    def item_name(self, ctx):
        item_name = ctx.item_names.lookup_in_slot(self.item, ctx.slot)
        return ctx.jsontozdoomtextparser.handle_node({
            "type": "item_id",
            "text": self.item,
            "player": self.receiving_player,
            "flags": self.item_flags,
        })

    def location_name(self, ctx):
        return ctx.jsontozdoomtextparser.handle_node({
            "type": "location_id",
            "text": self.location,
            "player": self.finding_player,
        })


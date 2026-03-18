// Tokens used to indicate that the player has access to or the automap for a
// level. These used to be special flags on the Region struct, now they're
// stored in the inventory table for better coupling between AP and UZ.
//
// The define sprites, not because the player is likely to ever see the items
// themselves, but because these are used to draw them as part of the check
// graphics.
//
// In a randomized wad, an empty subclass of each of these tokens exists for
// every map in the game.

#namespace GZAP;

class ::InventoryToken : Inventory {
  string map;
  property Map: map;
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INVENTORY.IGNORESKILL;
    +INVENTORY.UNTOSSABLE;
    +INVENTORY.UNDROPPABLE;
    +INVENTORY.QUIET;
  }
  States {
    Spawn:
      TNT1 A -1;
      STOP;
  }
}

class ::LevelAccess : ::InventoryToken {
  States {
    Spawn:
      AP00 A -1;
      STOP;
  }
}

class ::Automap : ::InventoryToken {
  States {
    Spawn:
      AP00 M -1;
      STOP;
  }
}

class ::LevelCleared : ::InventoryToken {}

// The in-player inventory item that holds all the Archipelago state for the
// player that needs to go into the savegame.
//
// This means:
// - what keys the player has
// - what levels the player has access or, and has completed
// - what locations the player has checked

#namespace GZAP;
#debug on;

// A "sub-keyring" for an individual level.
class ::Subring play {
  Map<int,bool> checked;
  Array<string> keys;
  bool access;
  bool cleared;

  // Add a key to the ring. Returns true if the key was new, false if it was a
  // duplicate.
  bool AddKey(string key) {
    if (HasKey(key)) {
      return false;
    }
    keys.Push(key);
    return true;
  }

  bool HasKey(string key) {
    return keys.Find(key) != keys.Size();
  }
}

class ::Keyring : Inventory {
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INVENTORY.IGNORESKILL;
    +INVENTORY.UNTOSSABLE;
    +INVENTORY.UNDROPPABLE;
    +INVENTORY.QUIET;
  }

  Map<string, ::Subring> map_to_keys;
  Map<string, bool> known_keys;

  ::Subring GetRing(string map) {
    let ring = map_to_keys.Get(map);
    if (!ring) {
      ring = new("::Subring");
      map_to_keys.Insert(map, ring);
    }
    return ring;
  }

  void AddKey(string map, string key) {
    known_keys.Insert(key, true);
    let ring = GetRing(map);
    if (ring.AddKey(key) && map == level.MapName) {
      UpdateKeys();
    }
  }

  // Remove any keys that the player shouldn't have from their inventory, and
  // add any keys that they're missing.
  void UpdateKeys() {
    let ring = GetRing(level.MapName);

    foreach (key, val : known_keys) {
      if (ring.HasKey(key)) {
        owner.GiveInventoryType(key);
      } else {
        owner.TakeInventory(key, 999);
      }
    }
  }

  void MarkAccessible(string map) {
    GetRing(map).access = true;
  }

  void MarkClear(string map) {
    GetRing(map).cleared = true;
  }
}

// The in-player inventory item that holds all the Archipelago state for the
// player that needs to go into the savegame.
//
// This means:
// - what keys the player has
// - what levels the player has access to, has maps for, and has completed
// - what locations the player has checked
//
// These are divided up by level so that for the expensive cases that run on
// level load, only the current level needs to be checked.

#namespace GZAP;
#debug on;

// A "sub-keyring" for an individual level.
class ::Subring play {
  Map<int,bool> checked;
  // TODO: this should probably be a map, and it should be populated when the
  // data package is initialized with all false values, so that we know not just
  // what keys the player has but what keys they could potentially have.
  // This also lets us populate and sort known_keys at startup.
  Array<string> keys;
  bool access;
  bool automap;
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

  static clearscope ::Keyring Get(uint player) {
    return ::Keyring(players[player].mo.FindInventory("::Keyring"));
  }

  ::Subring GetRingIfExists(string map) const {
    return map_to_keys.Get(map);
  }

  ::Subring GetRing(string map) {
    let ring = GetRingIfExists(map);
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
      UpdateInventory();
    }
  }

  // Remove any keys that the player shouldn't have from their inventory, and
  // add any keys that they're missing. Also give them the automap if they
  // should have it.
  void UpdateInventory() {
    let ring = GetRing(level.MapName);

    if (ring.automap) {
      owner.GiveInventoryType("MapRevealer");
    }

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

  bool IsAccessible(string map) {
    return GetRing(map).access;
  }

  void MarkMapped(string map) {
    GetRing(map).automap = true;
  }

  bool IsMapped(string map) {
    return GetRing(map).automap;
  }

  void MarkCleared(string map) {
    GetRing(map).cleared = true;
  }

  bool IsCleared(string map) {
    return GetRing(map).cleared;
  }

  void MarkChecked(string map, uint apid) {
    GetRing(map).checked.Insert(apid, true);
  }

  bool IsChecked(string map, uint apid) {
    return GetRing(map).checked.CheckKey(apid);
  }
}

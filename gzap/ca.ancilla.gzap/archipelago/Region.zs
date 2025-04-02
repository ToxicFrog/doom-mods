// Information about an entire map, modeled in AP as a Region.
//
// This contains not just the set of Locations in the region, but also per-level
// flags like whether the player has access to it at all and what keys they have
// for it.
//
// It's responsible for synchronizing the player's inventory when they enter the
// level, and contains some utility functions for managing the Locations inside
// it.
#namespace GZAP;
#debug off;

#include "./Location.zsc"

class ::Hint play {
  string player;
  string location;
}

class ::Peek play {
  string player;
  string item;
}

class ::Region play {
  string map;
  Array<::Location> locations;
  Map<string, bool> keys;
  // Hints tell you where items relevant to this level are.
  // Peeks tell you what items are contained in this level.
  // Indexes are fully qualified Archipelago names, e.g. "RedCard (MAP01)" or
  // "MAP01 - RocketLauncher".
  Map<string, ::Hint> hints;
  Map<string, ::Peek> peeks;
  bool access;
  bool automap;
  bool cleared;
  uint exit_id;

  static ::Region Create(string map, uint exit_id) {
    let region = ::Region(new("::Region"));
    region.map = map;
    region.exit_id = exit_id;
    return region;
  }

  void RegisterCheck(
      uint apid, string name,
      string orig_typename, string ap_typename, string ap_name,
      bool progression, Vector3 pos, bool unreachable = false) {
    let loc = ::Location(new("::Location"));
    loc.apid = apid;
    loc.name = name;
    loc.orig_typename = orig_typename;
    loc.ap_typename = ap_typename;
    loc.ap_name = ap_name;
    loc.progression = progression;
    loc.unreachable = unreachable;
    loc.checked = false;
    loc.pos = pos;
    loc.secret_sector = -1;
    locations.push(loc);
  }

  void RegisterSecretCheck(uint apid, string name, int sector, bool unreachable = false) {
    let loc = ::Location(new("::Location"));
    loc.apid = apid;
    loc.name = name;
    loc.secret_sector = sector;
    loc.unreachable = unreachable;
    loc.checked = false;
    locations.push(loc);
  }

  void ClearLocation(uint apid) {
    foreach (loc : locations) {
      if (loc.apid == apid) {
        loc.checked = true;
        return;
      }
    }
  }

  ::Location GetLocation(uint apid) {
    foreach (loc : locations) {
      if (loc.apid == apid) {
        DEBUG("GetLocation: found %d in %s", apid, map);
        return loc;
      }
    }
    return null;
  }

  uint LocationsChecked() const {
    uint found = 0;
    foreach (loc : locations) {
      if (loc.checked && !loc.unreachable) ++found;
    }
    return found;
  }

  uint LocationsTotal() const {
    uint total = 0;
    foreach (loc : locations) {
      if (!loc.unreachable) ++total;
    }
    return total;
  }

  // Return the name of the next item to hint for that's useful for this level.
  // If you don't have the level access, hints for that.
  // Otherwise, hints for the first key you don't have.
  // If you have access and keys, returns "".
  string NextHint() const {
    if (!self.access && !self.GetHint("Level Access")) {
      return string.format("Level Access (%s)", self.map);
    }

    foreach (k, v : self.keys) {
      if (!v && !self.GetHint(k)) {
        return string.format("%s (%s)", k, self.map);
      }
    }

    return "";
  }

  void RegisterHint(string item, string player, string location) {
    let hint = ::Hint(new("::Hint"));
    hint.player = player;
    hint.location = location;
    self.hints.Insert(item, hint);
    DEBUG("RegisterHint(%s): %s's %s", item, player, location);
  }

  // This takes the item name without the map qualifier, e.g. "RedCard", and
  // automatically qualifies it before looking it up.
  ::Hint GetHint(string item) const {
    let name = string.format("%s (%s)", item, self.map);
    // DEBUG("%s: GetHint(%s)", self.map, name);
    return self.hints.GetIfExists(name);
  }

  void RegisterPeek(string location, string player, string item) {
    let peek = ::Peek(new("::Peek"));
    peek.player = player;
    peek.item = item;
    self.peeks.Insert(location, peek);
    DEBUG("RegisterPeek(%s): %s for %s", location, item, player);
  }

  // Unlike GetHint this always takes the full location name.
  ::Peek GetPeek(string location) const {
    // DEBUG("GetPeek(%s)", location);
    return self.peeks.GetIfExists(location);
  }

  void RegisterKey(string key) {
    keys.Insert(key, false);
  }

  void AddKey(string key) {
    keys.Insert(key, true);
  }

  uint KeysFound() const {
    uint found = 0;
    foreach (_, v : keys) {
      if (v) ++found;
    }
    return found;
  }

  uint KeysTotal() const {
    return keys.CountUsed();
  }

  // Get the list of keys as comma-separated JSON strings.
  string KeyString() {
    string buf = "";
    foreach (k, v : keys) {
      if (!v) continue;
      buf.AppendFormat("%s\"%s\"", buf.Length() > 0 ? ", " : "", k);
    }
    return buf;
  }

  void UpdateInventory(PlayerPawn mo) {
    if (automap) {
      mo.GiveInventoryType("MapRevealer");
    }

    Array<string> keys_held;
    readonly<Inventory> item = mo.inv;
    while(item) {
      if (item is "Key") keys_held.Push(item.GetClassName());
      item = item.inv;
    }

    foreach (key : keys_held) {
      DEBUG("Removing key: %s", key);
      mo.TakeInventory(key, 999);
    }

    foreach (key, val : self.keys) {
      DEBUG("Add key? %s %d", key, val);
      if (val) mo.GiveInventoryType(key);
    }
  }
}

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

#include "./Location.zsc"

class ::Hint play {
  string player;
  string location;
}

class ::Region play {
  string map;
  Array<::Location> locations;
  Map<string, bool> keys;
  Map<string, ::Hint> hints;
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

  void RegisterCheck(uint apid, string name, bool progression, Vector3 pos, bool unreachable) {
    let loc = ::Location(new("::Location"));
    loc.apid = apid;
    loc.name = name;
    loc.progression = progression;
    loc.unreachable = unreachable;
    loc.checked = false;
    loc.pos = pos;
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
        return loc;
      }
    }
    return null;
  }

  uint LocationsChecked() const {
    uint found = 0;
    foreach (loc : locations) {
      if (loc.checked) ++found;
    }
    return found;
  }

  uint LocationsTotal() const {
    return locations.Size();
  }

  // Return the name of the next item to hint for that's useful for this level.
  // If you don't have the level access, hints for that.
  // Otherwise, hints for the first key you don't have.
  // If you have access and keys, returns "".
  // TODO: remember the hints and display them in the tooltip.
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
  }

  ::Hint GetHint(string item) const {
    return self.hints.GetIfExists(item);
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

    foreach (key, val : keys) {
      if (val) {
        mo.GiveInventoryType(key);
      } else {
        mo.TakeInventory(key, 999);
      }
    }
  }
}

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
#include "./RandoKey.zsc"

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
  // If nonzero, this map originally belonged to the given hubcluster.
  int hub;
  // Kept as an array so we can sort it for display.
  // Hopefully this doesn't become a performance issue.
  Array<::Location> locations;
  Map<string, ::RandoKey> keys;
  // Hints tell you where items relevant to this level are.
  // Peeks tell you what items are contained in this level.
  // Indexes are fully qualified Archipelago names, e.g. "RedCard (MAP01)" or
  // "MAP01 - RocketLauncher".
  Map<string, ::Hint> hints;
  Map<string, ::Peek> peeks;
  bool access;
  bool automap;
  bool cleared;
  ::Location exit_location;

  static ::Region Create(string map, int hub, uint exit_id) {
    let region = ::Region(new("::Region"));
    region.map = map;
    region.hub = hub;

    let exit = ::Location(new("::Location"));
    exit.apid = exit_id;
    exit.mapname = map;
    exit.name = string.format("%s - Exit", map);
    exit.secret_sector = -1;
    exit.unreachable = false;
    exit.checked = false;
    exit.is_virt = true;
    region.exit_location = exit;

    return region;
  }

  void DebugPrint() {
    console.printf("  - Region: %s%s [access=%d, clear=%d, automap=%d]",
        self.map, self.hub ? string.format(" (hubcluster %d)", self.hub) : "",
        self.access, self.cleared, self.automap);
    console.printf("    %d locations", self.locations.Size());
    console.printf("    %d keys:%s", self.keys.CountUsed(), self.DebugKeyString());
    console.printf("    %d hints", self.hints.CountUsed());
    foreach (item, hint : self.hints) {
      console.printf("    - %s: %s @ %s", item, hint.player, hint.location);
    }
    console.printf("    %d peeks", self.peeks.CountUsed());
    foreach (location, peek : self.peeks) {
      console.printf("    - %s: %s for %s", location, peek.item, peek.player);
    }
  }

  string DebugKeyString() {
    string buf;
    foreach (_, key : self.keys) {
      buf = buf .. " " .. key.typename;
    }
    return buf;
  }

  void RegisterCheck(
      uint apid, string name,
      string orig_typename, string ap_typename, string ap_name,
      bool progression, Vector3 pos, bool unreachable = false) {
    let loc = ::Location(new("::Location"));
    loc.apid = apid;
    loc.mapname = self.map;
    loc.name = name;
    loc.orig_typename = orig_typename;
    loc.ap_typename = ap_typename;
    loc.ap_name = ap_name;
    loc.progression = progression;
    loc.unreachable = unreachable;
    loc.checked = false;
    loc.pos = pos;
    loc.is_virt = false;
    loc.secret_sector = -1;
    locations.push(loc);
  }

  void RegisterSecretCheck(uint apid, string name, int sector, bool unreachable = false) {
    let loc = ::Location(new("::Location"));
    loc.apid = apid;
    loc.mapname = self.map;
    loc.name = name;
    loc.secret_sector = sector;
    loc.is_virt = true;
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

  void SortLocations() {
    // It's small, we just bubble sort.
    for (int i = self.locations.Size()-1; i > 0; --i) {
      for (int j = 0; j < i; ++j) {
        if (!self.locations[j].Order(self.locations[j+1])) {
          let tmp = self.locations[j];
          self.locations[j] = self.locations[j+1];
          self.locations[j+1] = tmp;
        }
      }
    }
  }

  string AccessTokenFQIN() const {
    return string.format("Level Access (%s)", self.map);
  }

  // Return the name of the next item to hint for that's useful for this level.
  // If you don't have the level access, hints for that.
  // Otherwise, hints for the first key you don't have.
  // If you have access and keys, returns "".
  string NextHint() const {
    if (!self.access && !self.GetHint(self.AccessTokenFQIN())) {
      return self.AccessTokenFQIN();
    }

    foreach (k, v : self.keys) {
      if (!v.held && !self.GetHint(v.FQIN())) {
        return v.FQIN();
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

  // If we remember a hint for the item with the given FQIN, returns it.
  // Otherwise returns null.
  ::Hint GetHint(string item) const {
    DEBUG("[%s] GetHint(%s) -> %d", self.map, item, self.hints.CheckKey(item));
    return self.hints.GetIfExists(item);
  }

  void RegisterPeek(string location, string player, string item) {
    let peek = ::Peek(new("::Peek"));
    peek.player = player;
    peek.item = item;
    self.peeks.Insert(location, peek);
    DEBUG("RegisterPeek(%s): %s for %s", location, item, player);
  }

  // Like GetHint but takes a location name and returns the peek, if we know one.
  ::Peek GetPeek(string location) const {
    // DEBUG("GetPeek(%s)", location);
    return self.peeks.GetIfExists(location);
  }

  void RegisterKey(::RandoKey key) {
    keys.Insert(key.typename, key);
  }

  uint KeysFound() const {
    uint found = 0;
    foreach (_, v : keys) {
      if (v.held) ++found;
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
      if (!v.held || !v.enabled) continue;
      // Uses just the typenames, since scopes must be non-overlapping for a
      // given keytype.
      buf.AppendFormat("%s\"%s\"", buf.Length() > 0 ? ", " : "", v.typename);
    }
    return buf;
  }

  void ToggleKey(string keytype) {
    let key = self.keys.GetIfExists(keytype);
    if (!key) {
      console.printf("ToggleKey(%s): no such key in %s", keytype, self.map);
      return;
    }
    key.enabled = !key.enabled;
    ::PlayEventHandler.GetState().UpdatePlayerInventory();
  }

  // TODO: ideally we should detect when the key is picked up and trigger this
  // immediately, rather than waiting for a level load/unload.
  void CheckForNewKeys(::RandoState apstate, PlayerPawn pawn) {
    Array<string> keys_held;
    readonly<Inventory> item = pawn.inv;
    while (item) {
      if (!(item is "Key")) {
        item = item.inv;
        continue;
      }

      let key = self.keys.GetIfExists(item.GetClassName());
      if (key) {
        item = item.inv;
        continue;
      }

      key = apstate.RegisterKey(level.mapname, item.GetClassName(), -1);
      key.held = true;
      item = item.inv;
    }
  }

  void UpdateInventory(PlayerPawn mo) {
    if (automap) {
      mo.GiveInventoryType("MapRevealer");
    }

    Array<string> keys_held;
    readonly<Inventory> item = mo.inv;
    while (item) {
      if (item is "Key") keys_held.Push(item.GetClassName());
      item = item.inv;
    }

    foreach (key : keys_held) {
      DEBUG("Removing key: %s", key);
      mo.TakeInventory(key, 999);
    }

    foreach (fqin, key : self.keys) {
      DEBUG("Add key? %s %d %d", fqin, key.held, key.enabled);
      if (!key.held || !key.enabled) continue;
      let key_item = mo.GiveInventoryType(key.typename);
      key_item.amount = 999;
    }
  }
}

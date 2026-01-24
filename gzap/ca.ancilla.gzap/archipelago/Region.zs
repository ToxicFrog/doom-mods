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
  // Lump name
  string map;
  // Transaction ID. Level select uses this to know when to redraw.
  uint txn;
  // If nonzero, this map originally belonged to the given hubcluster.
  int hub;
  // Kept as an array so we can sort it for display.
  // Hopefully this doesn't become a performance issue.
  Array<::Location> locations;
  Map<uint, ::Location> locations_by_id;
  // Key typename to key info struct. Only contains keys relevant to this level.
  Map<string, ::RandoKey> keys;
  // Hints tell you where items relevant to this level are.
  // Peeks tell you what items are contained in this level.
  // Indexes are fully qualified Archipelago names, e.g. "RedCard (MAP01)" or
  // "MAP01 - RocketLauncher".
  Map<string, ::Hint> hints;
  Map<string, ::Peek> peeks;
  bool access;
  bool automap;
  bool visited;
  bool cleared;
  ::Location exit_location;

  static ::Region Create(string map, int hub, uint exit_id) {
    let region = ::Region(new("::Region"));
    region.map = map;
    region.hub = hub;
    region.txn = 0;

    let exit = ::Location(new("::Location"));
    exit.apid = exit_id;
    exit.mapname = map;
    exit.name = string.format("%s - Exit", map);
    exit.secret_id = -1;
    exit.flags = AP_IS_PROGRESSION|AP_IS_USEFUL;
    exit.checked = false;
    exit.is_virt = true;
    region.exit_location = exit;

    return region;
  }

  void DebugPrint() {
    console.printf("  - Region: %s%s [access=%d, clear=%d, automap=%d, txn=%d]",
        self.map, ClusterDesc(), self.access, self.cleared, self.automap, self.txn);
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

  string ClusterDesc() {
    if (self.hub == 0) {
      return "";
    }
    let name = ::RC.Get().GetNameForCluster(self.hub);
    if (name == "") {
      return string.format(" (hubcluster %d)", self.hub);
    }
    return string.format(" (hubcluster %d: %s)", self.hub, name);
  }

  string DebugKeyString() {
    string buf;
    foreach (_, key : self.keys) {
      buf = buf .. " " .. key.typename;
    }
    return buf;
  }

  void RegisterCheck(
      uint apid, Vector3 pos, string name,
      string orig_typename, string ap_typename, string ap_name, uint flags) {
    ++txn;
    let loc = ::Location(new("::Location"));
    loc.mapname = self.map;
    loc.apid = apid;
    loc.pos = pos;
    loc.name = name;
    loc.orig_typename = orig_typename;
    loc.ap_typename = ap_typename;
    loc.ap_name = ap_name;
    loc.flags = flags;

    loc.checked = false;
    loc.is_virt = false;
    loc.secret_id = -1;

    locations.push(loc);
    locations_by_id.Insert(loc.apid, loc);
  }

  void RegisterSecretCheck(uint apid, string name, int secret_id, uint flags) {
    ++txn;
    let loc = ::Location(new("::Location"));
    loc.mapname = self.map;
    loc.apid = apid;
    loc.name = name;
    loc.secret_id = secret_id;
    loc.flags = flags;

    loc.is_virt = true;
    loc.checked = false;
    locations.push(loc);
    locations_by_id.Insert(loc.apid, loc);
  }

  void ClearLocation(uint apid) {
    let loc = GetLocation(apid);
    if (!loc) return;

    loc.checked = true;
    ++txn;
  }

  ::Location GetLocation(uint apid) const {
    if (locations_by_id.CheckKey(apid)) {
      DEBUG("GetLocation: found %d in %s", apid, map);
      return locations_by_id.GetIfExists(apid);
    }
    return null;
  }

  uint LocationsChecked() const {
    uint found = 0;
    foreach (loc : locations) {
      if (loc.checked && !loc.IsUnreachable()) ++found;
    }
    return found;
  }

  uint LocationsTotal() const {
    uint total = 0;
    foreach (loc : locations) {
      if (!loc.IsUnreachable()) ++total;
    }
    return total;
  }

  void SortLocations() {
    ++txn;
    // It's small, we just bubble sort.
    // TODO: ok on some settings it's actually quite large (high hundreds), so
    // maybe implement a better sort algorithm someday.
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

  string AccessFlagFQIN() const {
    return string.format("Level Access (%s)", self.map);
  }

  // Return the name of the next item to hint for that's useful for this level.
  // If you don't have the level access, hints for that.
  // Otherwise, hints for the first key you don't have.
  // If you have access and keys, returns "".
  string NextHint() const {
    if (!self.access && !self.GetHint(self.AccessFlagFQIN())) {
      return self.AccessFlagFQIN();
    }

    foreach (k, v : self.keys) {
      if (!v.held && !self.GetHint(v.FQIN())) {
        return v.FQIN();
      }
    }

    return "";
  }

  void RegisterHint(string item, string player, string location) {
    ++txn;
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
    ++txn;
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

  bool HasPeek(string location) const { return self.peeks.CheckKey(location); }

  void RegisterKey(::RandoKey key) {
    ++txn;
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

  ::RandoKey GetKey(string typename) const {
    return self.keys.GetIfExists(typename);
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

  void UpdateInventory(PlayerPawn mo) {
    if (automap) {
      mo.GiveInventoryType("MapRevealer");
    }

    Map<string, bool> keys_to_add;
    foreach (keytype, key : self.keys) {
      if (!key.held || !key.enabled) continue;
      DEBUG("keys_to_add: %s", keytype);
      keys_to_add.Insert(keytype, true);
    }

    Map<string, bool> keys_to_remove;
    readonly<Inventory> item = mo.inv;
    while (item) {
      if (item is "Key" || item is "PuzzleItem") {
        if (keys_to_add.CheckKey(item.GetClassName())) {
          DEBUG("keys_to_add: %s is already present in inventory", item.GetClassName());
          keys_to_add.Remove(item.GetClassName());
        } else {
          DEBUG("keys_to_remove: %s", item.GetClassName());
          keys_to_remove.Insert(item.GetClassName(), true);
        }
      }
      item = item.inv;
    }

    foreach (keytype, _ : keys_to_remove) {
      DEBUG("Removing key: %s", keytype);
      mo.TakeInventory(keytype, 999);
    }

    foreach (keytype, _ : keys_to_add) {
      DEBUG("Adding key: %s", keytype);
      let key_item = Inventory(mo.Spawn(keytype));
      key_item.amount = 999;
      key_item.ClearCounters();
      key_item.CallTryPickup(mo);
    }
  }
}

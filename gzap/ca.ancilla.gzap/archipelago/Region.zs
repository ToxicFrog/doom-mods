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
#include "./Subregion.zsc"
#include "../actors/Tokens.zsc"

class ::Hint play {
  string player;
  string location;
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
  // Set of weapons the player should have when in this level.
  Map<string, bool> weapons;
  // Hints tell you where items relevant to this level are.
  // Peeks tell you what items are contained in this level.
  // Indexes are fully qualified Archipelago names, e.g. "RedCard (MAP01)" or
  // "MAP01 - RocketLauncher".
  Map<string, ::Hint> hints;
  // Whether the player has visited the level at any point.
  bool visited;
  // AP location that gets checked when you exit the level.
  // TODO: decouple this from the cleared flag so we can randomize anything we
  // want into it.
  ::Location exit_location;
  // The player's last known position in this map. Can be used to return the
  // player to their saved position when levelporting.
  Vector3 player_position;
  // Subregions defined in this region using ap-region. Used for logic development.
  Map<string, ::Subregion> subregions;

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
    exit.collected = false;
    exit.is_virt = true;
    region.exit_location = exit;

    return region;
  }

  void DebugPrint() {
    console.printf("  - Region: %s%s [access=%d, clear=%d, automap=%d, txn=%d]",
        self.map, ClusterDesc(), self.CanAccess(), self.IsCleared(), self.HasAutomap(), self.txn);
    console.printf("    %d locations", self.locations.Size());
    console.printf("    %d keys:%s", self.keys.CountUsed(), self.DebugKeyString());
    console.printf("    %d hints", self.hints.CountUsed());
    foreach (name, subregion: self.subregions) {
      console.printf("    - %s/%s: %s", self.map, name, subregion.PrereqsAsString());
    }
    foreach (item, hint : self.hints) {
      console.printf("    - %s: %s @ %s", item, hint.player, hint.location);
    }
    int peeks = 0;
    foreach (location: self.locations) {
      if (location.peek) ++peeks;
    }
    console.printf("    %d peeks", peeks);
    foreach (location: self.locations) {
      if (location.peek) console.printf("    - %s: %s for %s", location.name, location.peek.item, location.peek.player);
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

  bool CanAccess() const {
    return ::PlayEventHandler.GetState().CountItem("GZAP_LevelAccess_"..self.map) > 0;
  }
  bool HasAutomap() const {
    return ::PlayEventHandler.GetState().CountItem("GZAP_Automap_"..self.map) > 0;
  }
  bool IsCleared() const {
    return ::PlayEventHandler.GetState().CountItem("GZAP_LevelCleared_"..self.map) > 0;
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
    loc.collected  = false;
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
    loc.collected  = false;
    locations.push(loc);
    locations_by_id.Insert(loc.apid, loc);
  }

  void CollectLocation(uint apid) {
    let loc = GetLocation(apid);
    if (!loc) return;

    loc.collected = true;
    ++txn;
  }

  ::Location GetLocation(uint apid) const {
    if (locations_by_id.CheckKey(apid)) {
      // DEBUG("GetLocation: found %d in %s", apid, map);
      return locations_by_id.GetIfExists(apid);
    }
    return null;
  }

  uint LocationsChecked() const {
    uint found = 0;
    foreach (loc : locations) {
      if (loc.IsChecked() && !loc.IsUnreachable()) ++found;
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
    DEBUG("Sorting locations for %s", self.map);
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
    return ::PlayEventHandler
      .GetState()
      .items_by_type
      .Get("GZAP_LevelAccess_"..self.map)
      .tag;
  }

  void SavePosition(Vector3 pos) {
    ++txn;
    self.player_position = pos;
  }

  void ClearSavedPosition() {
    ++txn;
    self.player_position = (0,0,0);
  }

  // Return the name of the next item to hint for that's useful for this level.
  // If you don't have the level access, hints for that.
  // Otherwise, hints for the first key you don't have.
  // If you have access and keys, returns "".
  string NextHint() const {
    if (!self.CanAccess() && !self.GetHint(self.AccessFlagFQIN())) {
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
    // DEBUG("[%s] GetHint(%s) -> %d", self.map, item, self.hints.CheckKey(item));
    return self.hints.GetIfExists(item);
  }

  void RegisterPeek(int location_id, string player, string item) {
    ++txn;
    let peek = ::Peek(new("::Peek"));
    peek.player = player;
    peek.item = item;
    let loc = self.GetLocation(location_id);
    DEBUG("RegisterPeek(%s): %s for %s", loc.name, item, player);
    loc.peek = peek;
    self.SortLocations();
  }

  void RegisterKey(::RandoKey key) {
    ++txn;
    keys.Insert(key.typename, key);
  }

  uint KeysFound() const {
    uint found = 0;
    foreach (_, v : keys) {
      // TODO: does not take into account stacking for multikeys.
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
    if (self.HasAutomap()) {
      mo.GiveInventoryType("MapRevealer");
    }

    Map<string, int> items_to_add;
    foreach (keytype, key : self.keys) {
      if (!key.held || !key.enabled) continue;
      DEBUG("keys_to_add: %s", keytype);
      items_to_add.Insert(keytype, key.held);
    }

    // Only do weapon restoration when not in pretuning mode. In pretuning mode,
    // if the game takes away the player's guns, we want to account for that in
    // the resulting logic!
    if (!::PlayEventHandler.Get().IsPretuning()) {
      DEBUG("UpdateInventory: %d items in weapon set", self.weapons.CountUsed());
      foreach (gun, _ : self.weapons) {
        DEBUG("weapons_to_add: + %s", gun);
        items_to_add.Insert(gun, 1);
      }
    }

    Map<string, bool> items_to_remove;
    readonly<Inventory> item = mo.inv;
    while (item) {
      if (items_to_add.CheckKey(item.GetClassName())) {
        DEBUG("items_to_add: %s is already present in inventory", item.GetClassName());
        items_to_add.Remove(item.GetClassName());
      } else if (item is "Key" || item is "PuzzleItem") {
        // Item should be subject to key management, is in player's inventory,
        // and should not be present in this map.
        // TODO: replace this with a more generic "is this item scoped" check.
        // Some AP items may be scoped but not be Key or PuzzleItem, especially
        // once we implement map-scoped weapon ownership.
        DEBUG("items_to_remove: %s", item.GetClassName());
        items_to_remove.Insert(item.GetClassName(), true);
      }
      item = item.inv;
    }

    foreach (itype, _ : items_to_remove) {
      DEBUG("Removing item: %s", itype);
      mo.TakeInventory(itype, 999);
    }

    foreach (itype, count : items_to_add) {
      DEBUG("Adding item: %s x %d", itype, count);
      let item = Inventory(mo.Spawn(itype));
      if (item is "Weapon") {
        ::PerLevelHandler.Get().AllowNextWeapon();
      }
      item.amount = count;
      item.ClearCounters();
      item.CallTryPickup(mo);
    }
  }
}

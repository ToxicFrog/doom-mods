// In-playsim randomizer state.
//
// Information about what we have and haven't checked, what items we have, etc.
// This is mostly accessed and manipulated via the PlayEventHandler, but we need
// to insert it into the playsim so that it can be saved and loaded. Hence this
// class. (It also keeps things more cleanly separated -- state management here,
// event processing in the PlayEventHandler.)

#namespace GZAP;
#debug off;

#include "./RandoItem.zsc"
#include "./RandoKey.zsc"
#include "./Region.zsc"
#include "./WinConditions.zsc"

class ::RandoState play {
  string slot_name; // Name of player in AP
  // Transaction number. Used to resolve disagreements between datascope and playscope
  // instances of the state when a savegame is loaded.
  int txn;
  int checksum_errors;
  int filter_index;
  // Lump name to Region
  Map<string, ::Region> regions;
  // Currently active subregion, if any
  ::Subregion subregion;
  // AP item ID to key information
  Map<int, ::RandoKey> keys;
  // Player inventory granted by the rando. Lives outside the normal in-game
  // inventory so it can hold things not normally part of +INVBAR.
  // An array so that (a) we can sort it, and (b) we can refer to entries by
  // index in a netevent.
  Array<::RandoItem> items;
  // Same inventory, but organized by type name instead of by display order.
  Map<string, ::RandoItem> items_by_type;
  // And again by Archipelago ID, so we know what to grant when passed an ID
  // from the server.
  Map<uint, ::RandoItem> items_by_apid;
  ::WinConditions win_conditions;

  static ::RandoState Create() {
    let apstate = ::RandoState(new("::RandoState"));
    apstate.win_conditions = new("::WinConditions");
    apstate.weapon_check_counter = -1;
    return apstate;
  }

  void DebugPrint() {
    console.printf("AP State [txn=%d, filter_index=%d]", self.txn, self.filter_index);

    console.printf("  %d regions", self.regions.CountUsed());
    foreach (name, region : self.regions) {
      region.DebugPrint();
    }

    console.printf("  %d keys", self.keys.CountUsed());
    foreach (apid, key : self.keys) {
      key.DebugPrint();
    }

    console.printf("  %d items", self.items.Size());
    foreach (item : self.items) {
      item.DebugPrint();
    }
  }

  void RegisterMap(string map, string checksum, int hub, uint exit_apid) {
    DEBUG("Registering map: %s (exit: %d)", map, exit_apid);
    if (checksum != LevelInfo.MapChecksum(map)) {
      console.printfEX(PRINT_HIGH, "\c[RED]ERROR:\c- Map %s has checksum \c[RED]%s\c-, but the randomizer expected \c[CYAN]%s\c-.",
        map, LevelInfo.MapChecksum(map), checksum);
      ++checksum_errors;
      // The user will get a popup when they first enter the game, if any errors were recorded.
    }

    regions.Insert(map, ::Region.Create(map, hub, exit_apid));
  }

  bool did_warning;
  bool ShouldWarn() const {
    if (did_warning) return false;
    if (::PlayEventHandler.Get().IsPretuning()) return false;
    // Kind of a gross hack to handle the fact that ITYTD/NM have different filter
    // IDs even if they result in the same actor placement.
    return (checksum_errors > 0)
      || (::Util.GetSpawnFilterIndex() != self.filter_index);
  }

  ::RandoKey RegisterKey(string scope, string tag, string typename, uint apid) {
    DEBUG("RegisterKey %s (type %s) for scope %s as %d", tag, typename, scope, apid);
    let key = ::RandoKey.Create(scope, tag, typename);
    keys.Insert(apid, key);
    return key;
  }

  ::RandoKey FindKeyByFQIN(string fqin) {
    // This is currently only used when receiving a new hint, so we keep it
    // simple and just do a linear search.
    foreach (_, key : self.keys) {
      if (key.FQIN() == fqin) return key;
    }
    return null;
  }

  ::RandoItem RegisterItem(uint apid, string typename, string ap_name) {
    DEBUG("RegisterItem: %d [%s] %s", apid, typename, ap_name);
    let item = ::RandoItem.Create(typename, ap_name);
    self.items.Push(item);
    self.items_by_type.Insert(typename, item);
    if (apid) {
      self.items_by_apid.Insert(apid, item);
    }
    ++txn;
    return item;
  }

  void RegisterCheck(
      // Information about the location
      string map, uint apid, Vector3 pos, string name, string orig_typename,
      // Information about the item it contains
      string ap_typename, string ap_name, uint flags) {
    GetRegion(map).RegisterCheck(apid, pos, name, orig_typename, ap_typename, ap_name, flags);
  }

  void RegisterSecretCheck(string map, uint apid, string name, int secret_id, uint flags) {
    GetRegion(map).RegisterSecretCheck(apid, name, secret_id, flags);
  }

  // Called when we get a HINT message from AP.
  // If a key exists that exactly matches the given FQIN, we assume it's a hint
  // for that key, and register it on every region that the key belongs to.
  // Otherwise we assume the scope is a level name and register the hint in just
  // that level on the assumption it's an access flag or a map or something.
  // Unscoped hints (e.g. "your BFG is at...") are not currently supported in-game.
  void RegisterHint(string scope, string fqin, string player, string location) {
    let key = FindKeyByFQIN(fqin);
    if (key) {
      foreach (map, _ : key.maps) {
        let region = self.GetRegion(map);
        if (!region) continue;
        region.RegisterHint(fqin, player, location);
      }
      return;
    }

    let region = self.GetRegion(scope);
    if (!region) return;
    region.RegisterHint(fqin, player, location);
  }

  void SortItems() {
    // It's small, we just bubble sort.
    for (int i = self.items.Size()-1; i > 0; --i) {
      for (int j = 0; j < i; ++j) {
        if (!self.items[j].Order(self.items[j+1])) {
          let tmp = self.items[j];
          self.items[j] = self.items[j+1];
          self.items[j+1] = tmp;
        }
      }
    }
  }

  void SortLocations() {
    foreach (region : self.regions) {
      region.SortLocations();
    }
  }

  int CountItem(string typename) {
    if (self.items_by_type.CheckKey(typename)) {
      return self.items_by_type.Get(typename).total;
    } else {
      return -1;
    }
  }

  ::RandoItem FindItem(string typename) {
    return self.items_by_type.GetIfExists(typename);
  }

  bool HasWeapon(string typename) {
    DEBUG("HasWeapon? %s = %d", typename, CountItem(typename));
    return CountItem(typename) > 0;
  }

  bool HasWeaponSlot(int query_slot) {
    let slots = players[0].weapons;
    let pawn = players[0].mo;
    for (int n = 0; n < slots.SlotSize(query_slot); ++n) {
      let cls = slots.GetWeapon(query_slot, n);
      DEBUG("HasWeaponSlot? %d: checking %s", query_slot, cls.GetClassName());
      if (pawn.FindInventory(cls)) return true;
    }
    DEBUG("HasWeaponSlot? %d - giving up", query_slot);
    return false;
  }

  // Grant the player the item with the given ID.
  // If count is nonzero, the total item count is SET TO that value.
  // Otherwise, the current count is increased by one.
  void GrantItem(uint apid, uint count = 0) {
    ++txn;
    DEBUG("GrantItem: %d", apid);
    if (keys.CheckKey(apid)) {
      let key = keys.Get(apid);
      ::Util.announce("$GZAP_GOT_ITEM", key.FQIN());
      key.Increment(self);
      UpdatePlayerInventory();
      UpdateStatus();

    } else if (items_by_apid.CheckKey(apid)) {
      let item = items_by_apid.Get(apid);
      UpdateItemCount(item, count);
      // If the item is a map-scoped inventory token, update the txn for the
      // corresponding map region so that the level select screen knows to update.
      Class<::InventoryToken> itype = item.typename;
      if (itype) {
        let region = self.GetRegion(GetDefaultByType(itype).map);
        if (region) region.txn++;
      }

    } else {
      console.printf("Unknown item ID from Archipelago: %d", apid);
    }
  }

  void GrantItemByName(string typename, uint count = 0) {
    if (!self.items_by_type.CheckKey(typename)) {
      // Unknown item type, *but*, that just means AP doesn't know about it so
      // it's not in our initial item table. It might still exist in the wad,
      // in which case we can create a table entry for it on the spot.
      UpdateItemCount(self.RegisterItem(0, typename, ""), count);
      self.SortItems();
    } else{
      UpdateItemCount(self.items_by_type.Get(typename), count);
    }
  }

  void UpdateItemCount(::RandoItem item, uint count = 0) {
    if (count) {
      // ITEM message from client, force local count to match server.
      item.SetTotal(count);
    } else {
      // Singleplayer mode, just give them one.
      ::Util.announce("$GZAP_GOT_ITEM", item.tag);
      item.Inc();
    }

    UpdatePlayerInventory();
    UpdateStatus();
  }

  // For each item we have, look at the other apstate, and treat its "copies of
  // this item vended" counter for this item as taking precedence over ours.
  // This is used when reloading an earlier save, so that we remember what items
  // we have found, but rewind any item grants issued since the save.
  void CopyItemUsesFrom(::RandoState other) {
    foreach (typename, item : self.items_by_type) {
      if (other.items_by_type.CheckKey(typename)) {
        item.vended = other.items_by_type.Get(typename).vended;
      } else {
        // We hadn't found this yet in the other apstate.
        item.vended = 0;
      }
    }
  }

  void UseItemByName(string typename) {
    if (!items_by_type.CheckKey(typename)) return;
    DEBUG("UseItemByName: %s", typename);
    items_by_type.Get(typename).Replicate();
  }

  void GrabItem(string typename, int delta) {
    if (!items_by_type.CheckKey(typename)) return;
    let item = items_by_type.Get(typename);
    let grabbed = item.grabbed + delta;
    if (grabbed > item.Remaining() || grabbed < 0) return;
    item.grabbed = grabbed;
  }

  void CancelItemGrabs() {
    for (int n = 0; n < self.items.Size(); ++n) {
      self.items[n].grabbed = 0;
    }
  }

  void CommitItemGrabs() {
    for (int n = 0; n < self.items.Size(); ++n) {
      while (items[n].grabbed > 0) {
        items[n].grabbed--;
        items[n].Replicate();
      }
    }
  }

  bool dirty;
  void UpdatePlayerInventory() {
    if (!GetCurrentRegion()) return;
    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      if (!players[p].mo) continue;

      GetCurrentRegion().UpdateInventory(players[p].mo);
    }
    dirty = true;
  }

  void ToggleKey(string keytype) {
    ++txn;
    GetCurrentRegion().ToggleKey(keytype);
  }

  int weapon_check_counter;
  void UpdatePlayerWeapons() {
    if (weapon_check_counter < 0) return;
    --weapon_check_counter;
    if (weapon_check_counter == 0) {
      Map<string, bool> weapons;

      readonly<Inventory> item = players[0].mo.inv;
      while (item) {
        if (item is "Weapon") {
          DEBUG("UpdatePlayerWeapons: adding %s", item.GetClassName());
          weapons.Insert(item.GetClassName(), true);
        }
        item = item.inv;
      }

      foreach (region : regions) {
        region.weapons.Clear();
        foreach (weapon, _ : weapons) {
          // We should be able to:
          // region.weapons.Copy(weapons);
          // but for some reason this results in invalid iterator errors when
          // attempting to walk it later.
          region.weapons.Insert(weapon, true);
        }
      }
    }
  }

  void OnTick() {
    UpdatePlayerWeapons();
    if (!dirty) return;
    if (!GetCurrentRegion()) return;
    // TODO: per-player inventory will let us make this check per-player, for now
    // we just watch player[0].
    if (players[0].mo.vel.Length() == 0) return;
    DEBUG("Flushing pending item grants...");
    foreach (item : self.items) {
      int n = item.EnforceLimit();
      txn += n;
      if (n && item.IsWeapon()) {
        DEBUG("Vended a weapon (%s), starting weapon check counter", item.typename);
        weapon_check_counter = 7;
      }
    }
    dirty = false;
  }

  ::Region GetCurrentRegion() const {
    return regions.GetIfExists(level.MapName);
  }

  ::Region GetRegion(string map) const {
    return regions.GetIfExists(map);
  }

  void DefineOrActivateSubregion(string name) {
    let region = GetCurrentRegion();
    if (!region) return;
    let subregion = region.subregions.GetIfExists(name);
    if (!subregion) {
      subregion = ::Subregion.Create(name, region);
      console.printf("Defined new subregion %s/%s [%s]", region.map, name, subregion.PrereqsAsString());
    } else {
      console.printf("Activated existing subregion %s/%s [%s]", region.map, name, subregion.PrereqsAsString());
    }
    self.subregion = subregion;
  }

  void ClearSubregion() {
    if (self.subregion) {
      console.printf("Deactivated subregion %s", self.subregion.name);
      self.subregion = null;
    }
  }

  void OutputSubregions(bool all_maps) {
    if (all_maps) {
      console.printf("Writing all subregions of all maps to log...");
      foreach (region : self.regions) {
        region.OutputSubregions();
      }
    } else {
      let region = GetCurrentRegion();
      if (!region) {
        console.printf("Can't save subregions for a map that isn't randomized!");
        return;
      }
      console.printf("Saving all subregions for %s to log...", region.map);
      region.OutputSubregions();
    }
  }

  // Called when the server (or server stub in SP) reports that a location's
  // contents have been collected.
  void MarkLocationCollected(int apid) {
    ++txn;
    // It's safe to call CollectLocation() on a region that doesn't contain the location.
    foreach (_, region : self.regions) {
      region.CollectLocation(apid);
    }
    if (GetCurrentRegion()) {
      ::PerLevelHandler.Get().UpdateCheckPickups();
    }
  }

  void MarkLocationInLogic(int apid, string type) {
    ++txn;
    foreach (_, region : self.regions) {
      let loc = region.GetLocation(apid);
      if (loc) {
        DEBUG("Marking location %s: %s - %s", type, region.map, loc.name);
        if (type == "IL") {
          loc.track = AP_REACHABLE_IL;
        } else if (type == "OOL") {
          loc.track = AP_REACHABLE_OOL;
        } else {
          console.printf("[AP] Warning: unknown TRACK type for %s: %s", loc.name, type);
          loc.track = AP_UNREACHABLE;
        }
        region.SortLocations();
      }
    }
  }

  uint LevelsClear() const {
    uint n = 0;
    foreach (name, region : self.regions) {
      if (region.IsCleared()) ++n;
    }
    return n;
  }

  uint LevelsTotal() const {
    return self.regions.CountUsed();
  }

  void UpdateStatus() {
    // Might want to expand this later to list levels cleared, items collected,
    // etc, for the use of external trackers, but for now it's just a simple
    // "are we winning?"
    if (win_conditions.Victorious(self)) {
      ::IPC.Send("STATUS", "{ \"victory\": true }");
    }
  }
}

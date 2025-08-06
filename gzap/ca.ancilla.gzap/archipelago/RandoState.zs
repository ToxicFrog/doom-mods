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
#include "./RegionDiff.zsc"
#include "./WinConditions.zsc"

class ::RandoState play {
  string slot_name; // Name of player in AP
  // Transaction number. Used to resolve disagreements between datascope and playscope
  // instances of the state when a savegame is loaded.
  int txn;
  int checksum_errors;
  int filter;
  // Lump name to Region
  Map<string, ::Region> regions;
  // AP item ID to gzdoom typename
  Map<int, string> item_apids;
  // AP item ID to special token IDs -- level access, automap, clear flag
  Map<int, ::RegionDiff> tokens;
  // AP item ID to key information
  Map<int, ::RandoKey> keys;
  // Player inventory granted by the rando. Lives outside the normal in-game
  // inventory so it can hold things not normally part of +INVBAR.
  // An array so that (a) we can sort it, and (b) we can refer to entries by
  // index in a netevent.
  Array<::RandoItem> items;
  ::WinConditions win_conditions;

  static ::RandoState Create() {
    let apstate = ::RandoState(new("::RandoState"));
    apstate.win_conditions = new("::WinConditions");
    return apstate;
  }

  void DebugPrint() {
    console.printf("AP State [txn=%d, filter=%d]", self.txn, self.filter);

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

  // TODO: We can do better with key/token management here.
  // In particular, if we reify all the tokens as in-game items, we no longer
  // need to pass them as extra IDs to RegisterMap. Instead we define a new
  // RegisterToken() that behaves similar to RegisterKey, except it spawns
  // the corresponding token and sets the map field on it, and on pickup it
  // sets the requisite flags in the RandoState. This removes a whole bunch of
  // special cases.
  void RegisterMap(string map, string checksum, int hub, uint access_apid, uint map_apid, uint clear_apid, uint exit_apid) {
    DEBUG("Registering map: %s (tokens: %d %d %d %d)", map, access_apid, map_apid, clear_apid, exit_apid);
    if (checksum != LevelInfo.MapChecksum(map)) {
      console.printfEX(PRINT_HIGH, "\c[RED]ERROR:\c- Map %s has checksum \c[RED]%s\c-, but the randomizer expected \c[CYAN]%s\c-.",
        map, LevelInfo.MapChecksum(map), checksum);
      ++checksum_errors;
      // The user will get a popup when they first enter the game, if any errors were recorded.
    }

    regions.Insert(map, ::Region.Create(map, hub, exit_apid));

    // We need to bind these to the map name somehow, oops.
    if (access_apid) tokens.Insert(access_apid, ::RegionDiff.CreateFlags(map, true, false, false));
    if (map_apid) tokens.Insert(map_apid, ::RegionDiff.CreateFlags(map, false, true, false));
    if (clear_apid) tokens.Insert(clear_apid, ::RegionDiff.CreateFlags(map, false, false, true));
  }

  bool did_warning;
  bool ShouldWarn() const {
    if (did_warning) return false;
    // Kind of a gross hack to handle the fact that ITYTD/NM have different filter
    // IDs even if they result in the same actor placement.
    return (checksum_errors > 0)
      || (::Util.GetFilterName(::Util.GetCurrentFilter()) != ::Util.GetFilterName(filter));
  }

  ::RandoKey RegisterKey(string scope, string typename, uint apid) {
    DEBUG("RegisterKey %s for scope %s as %d", typename, scope, apid);
    let key = ::RandoKey.Create(scope, typename);
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

  void RegisterItem(string typename, uint apid) {
    DEBUG("RegisterItem: %s %d", typename, apid);
    item_apids.Insert(apid, typename);
  }

  void RegisterCheck(
      // Information about the location
      string map, uint apid, Vector3 pos, string name, string orig_typename,
      // Information about the item it contains
      string ap_typename, string ap_name, uint flags) {
    GetRegion(map).RegisterCheck(apid, pos, name, orig_typename, ap_typename, ap_name, flags);
  }

  void RegisterSecretCheck(string map, uint apid, string name, int sector, uint flags) {
    GetRegion(map).RegisterSecretCheck(apid, name, sector, flags);
  }

  // Called when we get a HINT message from AP.
  // If a key exists that exactly matches the given FQIN, we assume it's a hint
  // for that key, and register it on every region that the key belongs to.
  // Otherwise we assume the scope is a level name and register the hint in just
  // that level on the assumption it's an access token or a map or something.
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

  int, ::RandoItem FindItem(string typename) {
    for (int n = 0; n < self.items.Size(); ++n) {
      if (self.items[n].typename == typename) {
        return n, items[n];
      }
    }
    return -1, null;
  }

  bool HasWeapon(string typename) {
    let [count, item] = FindItem(typename);
    DEBUG("HasWeapon? %s = %d", typename, count);
    // We make the optimistic assumption that, since Replicate() spawns the
    // item for all players, we just need to check player 0 (here and below).
    return count >= 0 || players[0].mo.FindInventory(typename);
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
    if (tokens.CheckKey(apid)) {
      // Count doesn't matter, you either have it or you don't.
      let diff = tokens.Get(apid);
      diff.Apply(GetRegion(diff.map));
    } else if (keys.CheckKey(apid)) {
      let key = keys.Get(apid);
      ::Util.announce("$GZAP_GOT_ITEM", key.FQIN());
      key.MarkHeld(self);
    } else if (item_apids.CheckKey(apid)) {
      let typename = item_apids.Get(apid);
      let [idx, item] = FindItem(typename);
      if (idx < 0) {
        item = ::RandoItem.Create(typename);
        self.items.Push(item);
        self.SortItems();
      }
      if (count) {
        // ITEM message from client, force local count to match server.
        item.SetTotal(count);
      } else {
        // Singleplayer mode, just give them one.
        ::Util.announce("$GZAP_GOT_ITEM", item.tag);
        item.Inc();
      }
    } else {
      console.printf("Unknown item ID from Archipelago: %d", apid);
    }

    UpdatePlayerInventory();
    UpdateStatus();
  }

  // For each item we have, look at the other apstate, and treat its "copies of
  // this item vended" counter for this item as taking precedence over ours.
  void CopyItemUsesFrom(::RandoState other) {
    foreach (item : self.items) {
      let [idx, other_item] = other.FindItem(item.typename);
      if (idx < 0) {
        // We hadn't found this yet in the other apstate.
        item.vended = 0;
      } else {
        item.vended = other_item.vended;
      }
    }
  }

  void UseItem(uint idx) {
    ++txn;
    items[idx].Replicate();
    // UpdateStatus();
  }

  void UseItemByName(string name) {
    let [idx,item] = FindItem(name);
    DEBUG("UseItemByName: %s -> %d", name, idx);
    if (idx >= 0) UseItem(idx);
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

  void OnTick() {
    if (!dirty) return;
    if (!GetCurrentRegion()) return;
    // TODO: per-player inventory will let us make this check per-player, for now
    // we just watch player[0].
    if (players[0].mo.vel.Length() == 0) return;
    DEBUG("Flushing pending item grants...");
    foreach (item : self.items) {
      txn += item.EnforceLimit();
    }
    dirty = false;
  }

  ::Region GetCurrentRegion() const {
    return regions.GetIfExists(level.MapName);
  }

  ::Region GetRegion(string map) const {
    return regions.GetIfExists(map);
  }

  void MarkLocationChecked(int apid) {
    ++txn;
    // It's safe to call ClearLocation() on a region that doesn't contain the location.
    foreach (_, region : self.regions) {
      region.ClearLocation(apid);
    }
    // UpdateStatus();
  }

  void MarkLocationInLogic(int apid, string type) {
    ++txn;
    foreach (_, region : self.regions) {
      let loc = region.GetLocation(apid);
      if (loc) {
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
      if (region.cleared) ++n;
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

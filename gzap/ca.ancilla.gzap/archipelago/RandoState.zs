// In-playsim randomizer state.
//
// Information about what we have and haven't checked, what items we have, etc.
// This is mostly accessed and manipulated via the PlayEventHandler, but we need
// to insert it into the playsim so that it can be saved and loaded. Hence this
// class. (It also keeps things more cleanly separated -- state management here,
// event processing in the PlayEventHandler.)

#namespace GZAP;
#debug off;

#include "./Region.zsc"
#include "./RegionDiff.zsc"

class ::RandoItem play {
  // Class to instantiate
  string typename;
  // User-facing name
  string tag;
  // Internal category name
  string category;
  // Number left to dispense
  int held;
  // Number received from randomizer
  int total;

  static ::RandoItem Create(string typename) {
    Class<Actor> itype = typename;
    if (!itype) {
      console.printf("Invalid item type: '%s'", typename);
      return null;
    }
    let item = ::RandoItem(new("::RandoItem"));
    item.typename = typename;
    item.tag = GetDefaultByType(itype).GetTag();
    item.category = ::ScannedItem.ItemCategory(GetDefaultByType(itype));
    item.held = 0;
    item.total = 0;
    return item;
  }

  void SetTotal(int total) {
    if (total == self.total) return;
    self.held += total - self.total;
    self.total = total;
  }

  void Inc() {
    self.total += 1;
    self.held += 1;
  }

  void EnforceLimit() {
    int limit = GetLimit();
    DEBUG("Enforcing limits on %s: %d/%d limit %d", self.typename, self.held, self.total, limit);
    if (limit < 0) return;
    while (self.held > limit) {
      Replicate();
    }
  }

  bool ShouldAutoVend() {
    Array<string> patterns;
    ap_auto_vend.Split(patterns, " ", TOK_SKIPEMPTY);
    foreach (pattern : patterns) {
      if (self.category.IndexOf(pattern) >= 0 || self.typename.IndexOf(pattern) >= 0) {
        return true;
      }
    }
    return false;
  }

  int GetLimit() {
    if (self.ShouldAutoVend()) return 0;

    if (self.category == "weapon") {
      return ap_bank_weapons;
    } else if (self.category.IndexOf("-ammo") > -1) {
      return ap_bank_ammo;
    } else if (self.category.IndexOf("-armor") > -1) {
      return ap_bank_armour;
    } else if (self.category.IndexOf("-health") > -1) {
      return ap_bank_health;
    } else if (self.category == "powerup") {
      return ap_bank_powerups;
    } else{
      return ap_bank_other;
    }
  }

  // Thank you for choosing Value-Rep™!
  void Replicate() {
    DEBUG("Replicating %s", self.typename);
    if (!self.held) return;
    self.held -= 1;
    ::PerLevelHandler.Get().AllowDropsBriefly(2);
    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      if (!players[p].mo) continue;

      players[p].mo.A_SpawnItemEX(self.typename);
    }
  }

  // Used for sorting. Returns true if this item should be sorted before the
  // other item. At present we sort exclusively by name, disregarding count;
  // the menu code will skip over 0-count items.
  bool Order(::RandoItem other) {
    return self.tag < other.tag;
  }
}

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
  // AP item ID to map token
  Map<int, ::RegionDiff> map_apids;
  // Player inventory granted by the rando. Lives outside the normal in-game
  // inventory so it can hold things not normally part of +INVBAR.
  // An array so that (a) we can sort it, and (b) we can refer to entries by
  // index in a netevent.
  Array<::RandoItem> items;
  // Win conditions. Key is condition name, value is condition magnitude. Exact
  // meaning of the latter depends on the condition.
  Map<string, int> win_conditions;

  // TODO: We can do better with key/token management here.
  // In particular, if we reify all the tokens as in-game items, we no longer
  // need to pass them as extra IDs to RegisterMap. Instead we define a new
  // RegisterToken() that behaves similar to RegisterKey, except it spawns
  // the corresponding token and sets the map field on it, and on pickup it
  // sets the requisite flags in the RandoState. This removes a whole bunch of
  // special cases.
  void RegisterMap(string map, string checksum, uint access_apid, uint map_apid, uint clear_apid, uint exit_apid) {
    DEBUG("Registering map: %s", map);
    if (checksum != LevelInfo.MapChecksum(map)) {
      console.printfEX(PRINT_HIGH, "\c[RED]ERROR:\c- Map %s has checksum \c[RED]%s\c-, but the randomizer expected \c[CYAN]%s\c-.",
        map, LevelInfo.MapChecksum(map), checksum);
      ++checksum_errors;
      // The user will get a popup when they first enter the game, if any errors were recorded.
    }

    regions.Insert(map, ::Region.Create(map, exit_apid));

    // We need to bind these to the map name somehow, oops.
    if (access_apid) map_apids.Insert(access_apid, ::RegionDiff.CreateFlags(map, true, false, false));
    if (map_apid) map_apids.Insert(map_apid, ::RegionDiff.CreateFlags(map, false, true, false));
    if (clear_apid) map_apids.Insert(clear_apid, ::RegionDiff.CreateFlags(map, false, false, true));
  }

  bool did_warning;
  bool ShouldWarn() const {
    if (did_warning) return false;
    // Kind of a gross hack to handle the fact that ITYTD/NM have different filter
    // IDs even if they result in the same actor placement.
    return (checksum_errors > 0)
      || (::Util.GetFilterName(::Util.GetCurrentFilter()) != ::Util.GetFilterName(filter));
  }

  void RegisterKey(string map, string key, uint apid) {
    regions.Get(map).RegisterKey(key);
    map_apids.Insert(apid, ::RegionDiff.CreateKey(map, key));
  }

  void RegisterItem(string typename, uint apid) {
    DEBUG("RegisterItem: %s %d", typename, apid);
    item_apids.Insert(apid, typename);
  }

  void RegisterCheck(
      string map, uint apid, string name,
      string orig_typename, string ap_typename, string ap_name,
      bool progression, Vector3 pos, bool unreachable = false) {
    regions.Get(map).RegisterCheck(apid, name, orig_typename, ap_typename, ap_name, progression, pos, unreachable);
  }

  void RegisterSecretCheck(string map, uint apid, string name, int sector, bool unreachable = false) {
    Regions.Get(map).RegisterSecretCheck(apid, name, sector, unreachable);
  }

  void SortItems() {
    // It's small, we just bubble sort.
    for (int i = 0; i < self.items.Size()-1; ++i) {
      for (int j = i; j < self.items.Size()-1; ++j) {
        if (!self.items[j].Order(self.items[j+1])) {
          let tmp = self.items[j];
          self.items[j] = self.items[j+1];
          self.items[j+1] = tmp;
        }
      }
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
    if (map_apids.CheckKey(apid)) {
      // Count doesn't matter, you either have it or you don't.
      let diff = map_apids.Get(apid);
      let region = regions.Get(diff.map);
      diff.Apply(region);
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
    ::PlayEventHandler.Get().CheckVictory();
  }

  void UseItem(uint idx) {
    ++txn;
    items[idx].Replicate();
    ::PlayEventHandler.Get().CheckVictory();
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

  void OnTick() {
    if (!dirty) return;
    if (!GetCurrentRegion()) return;
    // TODO: per-player inventory will let us make this check per-player, for now
    // we just watch player[0].
    if (players[0].mo.vel.Length() == 0) return;
    DEBUG("Flushing pending item grants...");
    foreach (item : self.items) {
      item.EnforceLimit();
    }
    dirty = false;
  }

  ::Region GetCurrentRegion() {
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
    ::PlayEventHandler.Get().CheckVictory();
  }

  uint LevelsClear() const {
    uint n = 0;
    foreach (_, region : self.regions) {
      if (region.cleared) ++n;
    }
    return n;
  }

  uint LevelsTotal() const {
    return self.regions.CountUsed();
  }

  void RegisterWinCondition(string condition, int value) {
    self.win_conditions.Insert(condition, value);
  }

  uint LevelsRequired() const {
    return self.win_conditions.GetIfExists('levels-clear');
  }

  bool Victorious() const {
    return self.LevelsClear() >= self.LevelsRequired();
  }
}

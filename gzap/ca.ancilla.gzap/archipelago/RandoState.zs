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

  // Thank you for choosing Value-Rep™!
  void Replicate() {
    self.held -= 1;
    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      if (!players[p].mo) continue;

      players[p].mo.A_SpawnItemEX(self.typename);
    }
  }
}

class ::RandoState play {
  // Transaction number. Used to resolve disagreements between datascope and playscope
  // instances of the state when a savegame is loaded.
  int txn;
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
  // TODO: actually sort it
  Array<::RandoItem> items;

  void RegisterMap(string map, string checksum, uint access_apid, uint map_apid, uint clear_apid, uint exit_apid) {
    DEBUG("Registering map: %s", map);
    if (checksum != LevelInfo.MapChecksum(map)) {
      console.printfEX(PRINT_HIGH, "\c[RED]ERROR:\c- Map %s has checksum \c[RED]%s\c-, but the randomizer expected \c[CYAN]%s\c-.",
        map, LevelInfo.MapChecksum(map), checksum);
      // Continue -- maybe this is just a different version of the WAD with no substantive changes.
      // If the user gets a bunch of these messages and proceeds regardless, upon their own head be it.
    }

    regions.Insert(map, ::Region.Create(map, exit_apid));

    // We need to bind these to the map name somehow, oops.
    if (access_apid) map_apids.Insert(access_apid, ::RegionDiff.CreateFlags(map, true, false, false));
    if (map_apid) map_apids.Insert(map_apid, ::RegionDiff.CreateFlags(map, false, true, false));
    if (clear_apid) map_apids.Insert(clear_apid, ::RegionDiff.CreateFlags(map, false, false, true));
  }

  void RegisterKey(string map, string key, uint apid) {
    regions.Get(map).RegisterKey(key);
    map_apids.Insert(apid, ::RegionDiff.CreateKey(map, key));
  }

  void RegisterItem(string typename, uint apid) {
    DEBUG("RegisterItem: %s %d", typename, apid);
    item_apids.Insert(apid, typename);
  }

  void RegisterCheck(string map, uint apid, string name, bool progression, Vector3 pos) {
    regions.Get(map).RegisterCheck(apid, name, progression, pos);
  }

  int, ::RandoItem FindItem(string typename) {
    for (int n = 0; n < self.items.Size(); ++n) {
      if (self.items[n].typename == typename) {
        return n, items[n];
      }
    }
    return -1, null;
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
        idx = self.items.Push(item);
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

  void UpdatePlayerInventory() {
    if (!GetCurrentRegion()) return;
    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      if (!players[p].mo) continue;

      GetCurrentRegion().UpdateInventory(players[p].mo);
    }
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

  bool Victorious() const {
    return self.LevelsClear() == self.LevelsTotal();
  }
}

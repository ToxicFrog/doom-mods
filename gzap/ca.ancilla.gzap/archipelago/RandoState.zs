// In-playsim randomizer state.
//
// Information about what we have and haven't checked, what items we have, etc.
// This is mostly accessed and manipulated via the PlayEventHandler, but we need
// to insert it into the playsim so that it can be saved and loaded. Hence this
// class. (It also keeps things more cleanly separated -- state management here,
// event processing in the PlayEventHandler.)

#namespace GZAP;
#debug on;

#include "./Region.zsc"
#include "./RegionDiff.zsc"

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

  void RegisterMap(string map, uint access_apid, uint map_apid, uint clear_apid, uint exit_apid) {
    // console.printf("Registering map: %s", map);
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
    // console.printf("RegisterItem: %s %d", typename, apid);
    item_apids.Insert(apid, typename);
  }

  void RegisterCheck(string map, uint apid, string name, bool progression, Vector3 pos) {
    regions.Get(map).RegisterCheck(apid, name, progression, pos);
  }

  void GrantItem(uint apid) {
    ++txn;
    // console.printf("GrantItem: %d", apid);
    if (map_apids.CheckKey(apid)) {
      let diff = map_apids.Get(apid);
      let region = regions.Get(diff.map);
      diff.Apply(region);
    } else if (item_apids.CheckKey(apid)) {
      // TODO: if in-game, give this to the player
      // If not in-game, or if in the hubmap, enqueue it and give it to the player
      // when they enter a proper level.
      // TODO: try marking all inventory items as +INVBAR so the player can use
      // them when and as needed, or implementing our own inventory so that we
      // don't have to try to backpatch other mods' items.
      // console.printf("GrantItem %d (%s)", apid, item_apids.Get(apid));
      // TODO: this should use the item tag rather than typename.
      ::Util.announce("$GZAP_GOT_ITEM", item_apids.Get(apid));
      for (int p = 0; p < MAXPLAYERS; ++p) {
        if (!playeringame[p]) continue;
        if (!players[p].mo) continue;

        players[p].mo.A_SpawnItemEX(item_apids.Get(apid));
      }
    } else {
      console.printf("Unknown item ID from Archipelago: %d", apid);
    }

    UpdatePlayerInventory();
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
    return regions.Get(level.MapName);
  }

  ::Region GetRegion(string map) const {
    return regions.GetIfExists(map);
  }
}

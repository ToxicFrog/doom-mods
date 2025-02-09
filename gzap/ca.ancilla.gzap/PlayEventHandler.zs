// Play-time event handler.
// At play time, we need to handle a bunch of events:
// - we need to listen for events from the AP client and process them
// - we need to let the player move between levels
// - we need to let the player teleport to start of current level, or reset
//   the current level

#namespace GZAP;
#debug on;

#include "./PerMapInfo.zsc"

class ::PlayEventHandler : StaticEventHandler {
  int skill;
  bool early_exit;
  Map<string, ::PerMapInfo> maps;
  // Maps AP item IDs to gzDoom type names like RocketLauncher
  Map<int, string> item_apids;
  // Maps AP item IDs to internal updates to the map structure.
  // Fields set in this are copied to the canonical ::PerMapInfo for that map.
  Map<int, ::PerMapInfo> map_apids;

  override void OnRegister() {
    console.printf("PlayEventHandler starting up");
  }

  void RegisterSkill(int skill) {
    self.skill = skill;
  }

  void RegisterMap(string map, uint access_apid, uint map_apid, uint clear_apid, uint exit_apid) {
    console.printf("Registering map: %s", map);
    maps.Insert(map, ::PerMapInfo.Create(map, exit_apid));
    // We need to bind these to the map name somehow, oops.
    if (access_apid) map_apids.Insert(access_apid, ::PerMapInfo.CreatePartial(map, "", true, false, false));
    if (map_apid) map_apids.Insert(map_apid, ::PerMapInfo.CreatePartial(map, "", false, true, false));
    if (clear_apid) map_apids.Insert(clear_apid, ::PerMapInfo.CreatePartial(map, "", false, false, true));
  }

  void RegisterKey(string map, string key, uint apid) {
    maps.Get(map).RegisterKey(key);
    map_apids.Insert(apid, ::PerMapInfo.CreatePartial(map, key, false, false, false));
  }

  void RegisterItem(string typename, uint apid) {
    console.printf("RegisterItem: %s %d", typename, apid);
    item_apids.Insert(apid, typename);
  }

  void RegisterCheck(string map, uint apid, string name, bool progression, Vector3 pos, float angle) {
    maps.Get(map).RegisterCheck(apid, name, progression, pos, angle);
  }

  void Message(string message) {
    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      if (!players[p].mo) continue;
      players[p].mo.A_PrintBold(message);
    }
  }

  void GrantItem(uint apid) {
    if (map_apids.CheckKey(apid)) {
      let new_info = map_apids.Get(apid);
      let info = maps.Get(new_info.map);

      // TODO: this is kind of gross
      foreach (k,v : new_info.keys) {
        Message(string.format("Received %s (%s)", k, new_info.map));
        info.AddKey(k);
      }
      if (new_info.access) {
        Message(string.format("Received %s (%s)", "Level Access", new_info.map));
        info.access = true;
      }
      if (new_info.automap) {
        Message(string.format("Received %s (%s)", "Automap", new_info.map));
        info.automap = true;
      }
      if (new_info.cleared) {
        Message(string.format("\c[GOLD]%s: Level Clear!", new_info.map));
        info.cleared = true;
      }
    } else if (item_apids.CheckKey(apid)) {
      // TODO: if in-game, give this to the player
      // If not in-game, or if in the hubmap, enqueue it and give it to the player
      // when they enter a proper level.
      // TODO: try marking all inventory items as +INVBAR so the player can use
      // them when and as needed, or implementing our own inventory so that we
      // don't have to try to backpatch other mods' items.
      console.printf("GrantItem %d (%s)", apid, item_apids.Get(apid));
      for (int p = 0; p < MAXPLAYERS; ++p) {
        if (!playeringame[p]) continue;
        if (!players[p].mo) continue;

        players[p].mo.A_SpawnItemEX(item_apids.Get(apid));
      }
    }

    UpdatePlayerInventory();
  }

  void UpdatePlayerInventory() {
    if (!GetCurrentMapInfo()) return;
    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      if (!players[p].mo) continue;

      GetCurrentMapInfo().UpdateInventory(players[p].mo);
    }
  }

  ::CheckInfo FindCheck(Actor thing) {
    // Never replace a check with another check, that's a fast trip to
    // infinite loop town.
    if (thing is "::CheckPickup") return null;
    return GetCurrentMapInfo().FindCheck(thing.pos, thing.angle);
  }

  ::PerMapInfo GetCurrentMapInfo() {
    return maps.Get(level.MapName);
  }

  // Used by the generated data package to get a handle to the event handler
  // so it can install the location lists.
  static clearscope ::PlayEventHandler Get() {
    return ::PlayEventHandler(Find("::PlayEventHandler"));
  }

  static clearscope ::PerMapInfo GetMapInfo(string map) {
    return ::PlayEventHandler.Get().maps.GetIfExists(map);
  }

  override void WorldLoaded(WorldEvent evt) {
    if (level.MapName == "GZAPHUB") {
      Menu.SetMenu("ArchipelagoLevelSelectMenu");
      return;
    }

    // No mapinfo -- hopefully this just means it's a TITLEMAP added by a mod or
    // something, and not that we're missing the data package or the player has
    // been changemapping into places they shouldn't be.
    if (!GetMapInfo(level.MapName)) return;

    // TODO: if the player dies and reloads from start of level, checks that they
    // have already collected respawn.
    early_exit = false;
    foreach (Actor thing : ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT)) {
      let info = FindCheck(thing);
      if (!info) {
        // console.printf("No check for %s @ (%d,%d,%d)", thing.GetTag(), thing.pos.x, thing.pos.y, thing.pos.z);
        continue;  // No check corresponds to this actor.
      }

      thing.Destroy();
      if (!info.checked) {
        ::CheckPickup check = ::CheckPickup(Actor.Spawn("::CheckPickup", info.pos));
        check.apid = info.apid;
        check.name = info.name;
        check.progression = info.progression;
      }
    }

    UpdatePlayerInventory();
  }

  override void WorldUnloaded(WorldEvent evt) {
    if (evt.isSaveGame) return;
    if (self.early_exit) return;
    if (level.LevelNum == 0) return;
    if (!GetMapInfo(level.MapName)) return;

    CheckLocation(GetCurrentMapInfo().exit_id, string.format("%s - Exit", level.MapName));
    // GetCurrentMapInfo().cleared = true;
  }

  void CheckLocation(int apid, string name) {
    console.printf("AP-CHECK { \"id\": %d, \"name\": \"%s\" }",
      apid, name);
    EventHandler.SendNetworkEvent("ap-check", apid);
    GetCurrentMapInfo().ClearCheck(apid);
  }

  // TODO: we need an "ap-uncollectable" command for dealing with uncollectable
  // checks, like the flush key in GDT MAP12.
  // This sets a flag, and then:
  // - if a check is collected, that check is marked as uncollectable and the
  //   flag is cleared; or
  // - if the level is exited, all remaining checks in the level are collected
  //   and marked as uncollectable.
  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.name == "ap-level-select") {
      console.printf("%s %d", evt.name, evt.args[0]);
      let idx = evt.args[0];
      let info = LevelInfo.GetLevelInfo(idx);
      if (!info) {
        // oh no, no level of that number, not allowed
        console.printf("No level with number %d found.", idx);
        return;
      }
      self.early_exit = true;
      level.ChangeLevel(info.MapName, 0, CHANGELEVEL_NOINTERMISSION, skill);
    }
  }
}

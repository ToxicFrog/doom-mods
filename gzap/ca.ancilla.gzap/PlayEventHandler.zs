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

  void RegisterMap(string map, uint access_apid, uint map_apid, uint clear_apid) {
    console.printf("Registering map: %s", map);
    maps.Insert(map, ::PerMapInfo(new("::PerMapInfo")));
    // We need to bind these to the map name somehow, oops.
    if (access_apid) map_apids.Insert(access_apid, ::PerMapInfo.Create("", true, false, false));
    if (map_apid) map_apids.Insert(map_apid, ::PerMapInfo.Create("", false, true, false));
    if (clear_apid) map_apids.Insert(clear_apid, ::PerMapInfo.Create("", false, false, true));
  }

  void RegisterKey(string map, string key, uint apid) {
    maps.Get(map).RegisterKey(key);
    map_apids.Insert(apid, ::PerMapInfo.Create(key, false, false, false));
  }

  void RegisterItem(string typename, uint apid) {
    item_apids.Insert(apid, typename);
  }

  void RegisterCheck(string map, uint apid, string name, bool progression, Vector3 pos, float angle) {
    maps.Get(map).RegisterCheck(apid, name, progression, pos, angle);
  }

  // void GrantItem(uint apid) {
  //   if (item_apids.CheckKey(apid)) {
  //     // plop the item into the player's inventory
  //     // only valid once in game, so this can't be part of the data package!
  //   } else if (map_apids.CheckKey(apid)) {
  //     let new_info = map_apids.Get(apid);
  //     let info = maps.Get() //....we need to get the map name from map_apids...

  //     foreach (k,v : new_info.keys) {
  //       // also need to print a nice message for the player
  //       // maybe we need something other than PerMapInfo so we can store the item name?
  //       info.AddKey(k);
  //     }
  //     info.access = info.access || new_info.access;
  //     info.
  //   }
  //   let info,has_info = map_apids.GetI
  // }

  ::CheckInfo FindCheck(Actor thing) {
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
      // TODO: if the player tries to close this in the hub, immediately reopen it
      Menu.SetMenu("ArchipelagoLevelSelectMenu");
      return;
    }

    early_exit = false;
    foreach (Actor thing : ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT)) {
      let info = FindCheck(thing);
      if (!info) continue;  // No check corresponds to this actor.

      thing.Destroy();
      if (!info.checked) {
        ::CheckPickup check = ::CheckPickup(Actor.Spawn("::CheckPickup", info.pos));
        check.apid = info.apid;
        check.name = info.name;
        check.progression = info.progression;
      }
    }
  }

  override void WorldUnloaded(WorldEvent evt) {
    if (evt.isSaveGame) return;
    if (self.early_exit) return;
    if (level.LevelNum == 0) return;

    GetCurrentMapInfo().cleared = true;
  }

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

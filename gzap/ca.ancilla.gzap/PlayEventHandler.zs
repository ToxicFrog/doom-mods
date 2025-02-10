// Play-time event handler.
// At play time, we need to handle a bunch of events:
// - we need to listen for events from the AP client and process them
// - we need to let the player move between levels
// - we need to let the player teleport to start of current level, or reset
//   the current level

#namespace GZAP;
#debug on;

#include "./actors/AlarmClock.zsc"
#include "./actors/Check.zsc"
#include "./archipelago/Region.zsc"

class ::PlayEventHandler : StaticEventHandler {
  int skill;
  bool early_exit;
  Map<string, ::Region> regions;
  // Maps AP item IDs to gzDoom type names like RocketLauncher
  Map<int, string> item_apids;
  // Maps AP item IDs to internal updates to the map structure.
  // Fields set in this are copied to the canonical ::Region for that map.
  Map<int, ::Region> map_apids;

  override void OnRegister() {
    console.printf("PlayEventHandler starting up");
  }

  void RegisterSkill(int skill) {
    self.skill = skill;
  }

  void RegisterMap(string map, uint access_apid, uint map_apid, uint clear_apid, uint exit_apid) {
    // console.printf("Registering map: %s", map);
    regions.Insert(map, ::Region.Create(map, exit_apid));
    // We need to bind these to the map name somehow, oops.
    if (access_apid) map_apids.Insert(access_apid, ::Region.CreatePartial(map, "", true, false, false));
    if (map_apid) map_apids.Insert(map_apid, ::Region.CreatePartial(map, "", false, true, false));
    if (clear_apid) map_apids.Insert(clear_apid, ::Region.CreatePartial(map, "", false, false, true));
  }

  void RegisterKey(string map, string key, uint apid) {
    regions.Get(map).RegisterKey(key);
    map_apids.Insert(apid, ::Region.CreatePartial(map, key, false, false, false));
  }

  void RegisterItem(string typename, uint apid) {
    // console.printf("RegisterItem: %s %d", typename, apid);
    item_apids.Insert(apid, typename);
  }

  void RegisterCheck(string map, uint apid, string name, bool progression, Vector3 pos, float angle) {
    regions.Get(map).RegisterCheck(apid, name, progression, pos, angle);
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
      let info = regions.Get(new_info.map);

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
      // console.printf("GrantItem %d (%s)", apid, item_apids.Get(apid));
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

  ::Region GetCurrentMapInfo() {
    return regions.Get(level.MapName);
  }

  // Used by the generated data package to get a handle to the event handler
  // so it can install the location lists.
  static clearscope ::PlayEventHandler Get() {
    return ::PlayEventHandler(Find("::PlayEventHandler"));
  }

  static clearscope ::Region GetMapInfo(string map) {
    return ::PlayEventHandler.Get().regions.GetIfExists(map);
  }

  Map<int, ::Location> pending_locations;

  void Alarm() {
    foreach (loc : pending_locations) {
      console.printf(
        "Warning: couldn't find matching actor for check '%s', spawning it on player instead.",
        loc.name);
      ::CheckPickup.Create(loc, players[0].mo.pos);
    }
    UpdatePlayerInventory();
  }

  void ClearPending(::Location loc) {
    pending_locations.Remove(loc.apid);
  }

  void CleanupReopenedLevel() {
    foreach (::AlarmClock thing : ThinkerIterator.Create("::AlarmClock", Thinker.STAT_DEFAULT)) {
      thing.Destroy();
    }
    foreach (::CheckPickup thing : ThinkerIterator.Create("::CheckPickup", Thinker.STAT_DEFAULT)) {
      // At this point we have a divergence; the location referenced by the actor
      // and thus stored in the save game is not the same as the location stored
      // in the event handler.
      // So, we replace the saved one with the real one before evaluating whether
      // it's been checked.
      // TODO: we should probably just store the apid in the check and look up
      // the location that way by asking the eventhandler, rather than baking
      // the entire location into it, so that this workaround becomes unnecessary
      // -- it seems like a footgun waiting to happen.
      thing.location = pending_locations.Get(thing.location.apid);
      ClearPending(thing.location);
      if (thing.location.checked) {
        thing.ClearCounters();
        thing.Destroy();
      }
    }
  }

  override void WorldLoaded(WorldEvent evt) {
    if (level.MapName == "GZAPHUB") {
      Menu.SetMenu("ArchipelagoLevelSelectMenu");
      return;
    }

    // No mapinfo -- hopefully this just means it's a TITLEMAP added by a mod or
    // something, and not that we're missing the data package or the player has
    // been changemapping into places they shouldn't be.
    let info = GetMapInfo(level.MapName);
    if (!info) return;

    foreach (location : info.checks) {
      pending_locations.Insert(location.apid, location);
    }

    // If we're restoring a saved level state, we need to do additional cleanup
    // to get rid of pending alarm clocks, avoid double-spawning checks, and
    // despawn checks that have been collected.
    if (evt.IsSaveGame || evt.IsReopen) {
      CleanupReopenedLevel();
    } else {
      Actor.Spawn("::AlarmClock");
    }

    early_exit = false;
  }

  override void WorldThingSpawned(WorldEvent evt) {
    let thing = evt.thing;

    if (!thing) return;
    if (thing.bNOBLOCKMAP || thing.bNOSECTOR || thing.bNOINTERACTION || thing.bISMONSTER) return;
    if (!(thing is "Inventory")) return;

    if (thing is "::CheckPickup") {
      // Check has already been spawned, original item has already been deleted,
      // see if this check has already been found by the player and should be
      // despawned before they notice it.
      let thing = ::CheckPickup(thing);
      ClearPending(thing.location);
      if (thing.location.checked) {
        // console.printf("Clearing already-collected check: %s", thing.GetTag());
        thing.ClearCounters();
        thing.Destroy();
      }
      return;
    }

    let [check, distance] = FindCheckForActor(thing);
    if (check) {
      if (!check.checked) {
        // console.printf("Replacing %s with %s", thing.GetTag(), check.name);
        ::CheckPickup.Create(check, thing.pos);
      } else {
        // console.printf("Check %s has already been collected.", check.name);
      }
      ClearPending(check);
      thing.ClearCounters();
      thing.Destroy();
    }
  }

  // We consider two positions "close enough" to each other iff:
  // - d is less than MAX_DISTANCE, and
  // - only one of the coordinates differs.
  // This usually means an item placed on a conveyor or elevator configured to
  // start moving as soon as the level loads.
  bool IsCloseEnough(Vector3 p, Vector3 q, float d) {
    float MAX_DISTANCE = 2.0;
    return d <= MAX_DISTANCE
      && ((p.x == q.x && p.y == q.y)
          || (p.x == q.x && p.z == q.z)
          || (p.y == q.y && p.z == q.z));
  }

  ::Location, float FindCheckForActor(Actor thing) {
    ::Location closest;
    float min_distance = 1e10;
    if (pending_locations.CountUsed() == 0) return null, 0.0;
    foreach (_, check : pending_locations) {
      float distance = (thing.pos - check.pos).Length();
      if (distance == 0.0) {
        // Perfect, we found the exact check this corresponds to.
        return check, 0.0;
      } else if (distance < min_distance) {
        min_distance = distance;
        closest = check;
      }
    }
    // We found something, but it's not as close as we want it to be.
    if (IsCloseEnough(closest.pos, thing.pos, min_distance)) {
      // console.printf("WARN: Closest to %s @ (%f, %f, %f) was %s @ (%f, %f, %f)",
      //   thing.GetTag(), thing.pos.x, thing.pos.y, thing.pos.z,
      //   closest.name, closest.pos.x, closest.pos.y, closest.pos.z);
      return closest, min_distance;
    }
    // Not feeling great about this.
    return null, min_distance;
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
      // console.printf("%s %d", evt.name, evt.args[0]);
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

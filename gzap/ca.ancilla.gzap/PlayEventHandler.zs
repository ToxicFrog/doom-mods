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
#include "./archipelago/RandoState.zsc"
#include "./archipelago/Region.zsc"
#include "./IPC.zsc"

// TODO: for singleplayer rando, it should be possible to persist the state to
// the save file. We'd need to pull all the state out into a separate object
// and store it in the PlayerPawn. In OnWorldLoaded, if we have an empty state
// and the PlayerPawn doesn't, we overwrite our own state with its state.
class ::PlayEventHandler : StaticEventHandler {
  int skill;
  bool singleplayer;
  bool early_exit;
  // IPC stub for communication with Archipelago.
  ::IPC apclient;
  // Archipelago state manager.
  ::RandoState apstate;

  override void OnRegister() {
    console.printf("PlayEventHandler starting up");
    apclient = ::IPC(new("::IPC"));
    apstate = ::RandoState(new("::RandoState"));
  }

  // N.b. this uses the CVAR skill value, where 0 is ITYTD and 4 is Nightmare.
  void RegisterSkill(int skill, bool singleplayer) {
    self.skill = skill;
    self.singleplayer = singleplayer;
  }

  bool IsSingleplayer() const {
    return self.singleplayer;
  }

  // Used by the generated data package to get a handle to the event handler
  // so it can install the location lists.
  static clearscope ::PlayEventHandler Get() {
    return ::PlayEventHandler(Find("::PlayEventHandler"));
  }

  static clearscope ::RandoState GetState() {
    return ::PlayEventHandler.Get().apstate;
  }

  Map<int, ::Location> pending_locations;

  void Alarm() {
    foreach (loc : pending_locations) {
      console.printf(
        StringTable.Localize("$GZAP_MISSING_LOCATION"), loc.name);
      ::CheckPickup.Create(loc, players[0].mo.pos);
    }
    apstate.UpdatePlayerInventory();
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

  bool initialized;
  override void WorldLoaded(WorldEvent evt) {
    // Don't initialize IPC until after we're in-game; otherwise NetworkCommandProcess
    // doesn't get called and we end up missing events.
    if (!initialized) {
      initialized = true;
      apclient.Init();
    }

    if (level.MapName == "GZAPHUB") {
      Menu.SetMenu("ArchipelagoLevelSelectMenu");
      return;
    }

    // No mapinfo -- hopefully this just means it's a TITLEMAP added by a mod or
    // something, and not that we're missing the data package or the player has
    // been changemapping into places they shouldn't be.
    let region = apstate.GetRegion(level.MapName);
    if (!region) return;

    foreach (location : region.locations) {
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
    if (!apstate.GetRegion(level.MapName)) return;

    CheckLocation(apstate.GetCurrentRegion().exit_id, string.format("%s - Exit", level.MapName));
    // GetCurrentRegion().cleared = true;
  }

  void CheckLocation(int apid, string name) {
    // TODO: we need some way of marking checks unreachable.
    // We can't just check if the player has +NOCLIP because if they do, they
    // can't interact with the check in the first place. So probably we want
    // an 'ap-unreachable' netevent; if set, the next check touched is marked
    // as unreachable, or if the level is exited, all checks in it are marked
    // unreachable.
    ::IPC.Send("CHECK",
      string.format("{ \"id\": %d, \"name\": \"%s\", \"keys\": [%s] }",
        apid, name, apstate.GetCurrentRegion().KeyString()));
    EventHandler.SendNetworkEvent("ap-check", apid);
    apstate.GetCurrentRegion().ClearLocation(apid);
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

  override void UITick() {
    if (gametic % 35 != 0) return;
    apclient.ReceiveAll();
  }

  override void NetworkCommandProcess(NetworkCommand cmd) {
    // console.printf("NetworkCommandProcess %s", cmd.command);
    if (cmd.command == "ap-ipc:text") {
      string message = cmd.ReadString();
      console.printfEX(PRINT_TEAMCHAT, "%s", message);
    } else if (cmd.command == "ap-ipc:item") {
      int apid = cmd.ReadInt();
      apstate.GrantItem(apid);
    }
  }
}

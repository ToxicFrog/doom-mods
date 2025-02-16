// Handler for in-playsim level event stuff.
//
// This is "inside" the playsim, so it gets written to save files and so forth,
// and permits us to persist randomizer state across play sessions.

#namespace GZAP;
#debug off;

class ::PerLevelHandler : EventHandler {
  // Archipelago state manager.
  ::RandoState apstate;
  // Locations that we have yet to resolve when loading into the map.
  Map<int, ::Location> pending_locations;
  // If >0, number of ticks remaining to track spawning actors.
  int alarm;
  // If set, the player is leaving the level via the level select or similar
  // rather than by reaching the exit.
  bool early_exit;

  static clearscope ::PerLevelHandler Get() {
    return ::PerLevelHandler(Find("::PerLevelHandler"));
  }

  override void OnRegister() {
    DEBUG("OnRegister: tic=%d alarm=%d", level.MapTime, alarm);
    InitRandoState();
  }

  void InitRandoState() {
    let datastate = ::PlayEventHandler.GetState();

    if (self.apstate == null) {
      // Newly initialized, use the one from the PlayEventHandler.
      self.apstate = datastate;
    }

    if (self.apstate == datastate) {
      return;
    }

    // If we get this far, we probably just loaded a savegame, we have a saved
    // apstate, and we disagree with the StaticEventHandler on the contents.
    // Treat whichever one has the highest transaction count as the canonical one.
    DEBUG("APState conflict resolution: txn[d]=%d txn[p]=%d",
      ::PlayEventHandler.GetState().txn, apstate.txn);

    if (self.apstate.txn > datastate.txn) {
      DEBUG("Using state from playscope.");
      ::PlayEventHandler.Get().apstate = self.apstate;
    } else {
      DEBUG("Using state from datascope.");
      self.apstate = datastate;
    }
  }

  //// Handling for loading into the world. ////
  // For loading save games, WorldThingSpawned doesn't get called, so we just
  // call CleanupReopenedLevel() to deal with checks that were collected after
  // the game was saved and need to remain collected even across loads.
  // For new level entries, we use an AlarmClock to give ourselves a brief period
  // after level loading in which we track spawning actors and try to match them
  // up to locations, so that we can deal with stuff that doesn't exist on level
  // load and is swapped in a few tics later (e.g. Spawner trickery by mods).

  override void WorldLoaded(WorldEvent evt) {
    DEBUG("PLH WorldLoaded");

    if (level.MapName == "GZAPHUB") {
      Menu.SetMenu("ArchipelagoLevelSelectMenu");
      return;
    }
  }

  // Separate functions for handling "new map" and "game loaded" that are actually
  // called from the StaticEventHandler, since it's the only one that can tell
  // the difference.
  void OnNewMap() {
    // No mapinfo -- hopefully this just means it's a TITLEMAP added by a mod or
    // something, and not that we're missing the data package or the player has
    // been changemapping into places they shouldn't be.
    let region = apstate.GetRegion(level.MapName);
    if (!region) return;

    foreach (location : region.locations) {
      DEBUG("Enqueing location: %s", location.name);
      pending_locations.Insert(location.apid, location);
    }
    alarm = 10;

    early_exit = false;
  }

  void OnLoadGame() {
    // There's a fun edge case here where we load a save game made at the start
    // of the level while the alarm is still counting down. Fortunately this is
    // not actually a problem: this code will get rid of any obsolete already-
    // spawned checks, and WorldThingSpawned will prune newly spawning ones if
    // needed.
    DEBUG("PLH Cleanup");
    let region = apstate.GetRegion(level.MapName);
    foreach (::CheckPickup thing : ThinkerIterator.Create("::CheckPickup", Thinker.STAT_DEFAULT)) {
      // At this point, we may have a divergence, depending on whether the apstate
      // contained here or in the StaticEventHandler was deemed canonical.
      // In the latter case, the Location referenced in the actor came from the
      // save game, while the one in the apstate was carried across the save/load
      // barrier outside the playsim.
      // So, we replace the saved one with the real one before evaluating whether
      // it's been checked.
      // TODO: we should probably just store the apid in the check and look up
      // the location that way by asking the eventhandler, rather than baking
      // the entire location into it, so that this workaround becomes unnecessary
      // -- it seems like a footgun waiting to happen.
      DEBUG("CleanupReopened: id %d, matched %d",
          thing.location.apid, thing.location == region.GetLocation(thing.location.apid));
      thing.location = region.GetLocation(thing.location.apid);
      if (thing.location.checked) {
        thing.ClearCounters();
        thing.Destroy();
      }
    }
  }

  override void WorldTick() {
    if (!alarm) return;
    --alarm;
    if (alarm) return;
    DEBUG("PLH AlarmClockFired");
    foreach (loc : pending_locations) {
      console.printf(
        StringTable.Localize("$GZAP_MISSING_LOCATION"), loc.name);
      ::CheckPickup.Create(loc, players[0].mo);
    }
    apstate.UpdatePlayerInventory();
  }

  void ClearPending(::Location loc) {
    pending_locations.Remove(loc.apid);
  }

  //// Handling for individual actors spawning in. ////
  // This only runs when the alarm timer is set, i.e. for a few tics after level
  // initialization. We try to detect things spawning that should be replaced with
  // checks and do so. Any leftover checks will give automatically dispensed to
  // the player via WorldTick() above.

  override void WorldThingSpawned(WorldEvent evt) {
    if (!alarm) return;
    let thing = evt.thing;

    if (!thing) return;
    if (thing.bNOBLOCKMAP || thing.bNOSECTOR || thing.bNOINTERACTION || thing.bISMONSTER) return;
    if (!(thing is "Inventory")) return;

    if (thing is "::CheckPickup") {
      // Check has already been spawned, original item has already been deleted,
      // see if this check has already been found by the player and should be
      // despawned before they notice it.
      let thing = ::CheckPickup(thing);
      DEBUG("WorldThingSpawned(check) = %s", thing.location.name);
      ClearPending(thing.location);
      if (thing.location.checked) {
        DEBUG("Clearing already-collected check: %s", thing.GetTag());
        thing.ClearCounters();
        thing.Destroy();
      }
      return;
    }

    DEBUG("WorldThingSpawned(%s)", thing.GetTag());

    let [check, distance] = FindCheckForActor(thing);
    if (check) {
      if (!check.checked) {
        DEBUG("Replacing %s with %s", thing.GetTag(), check.name);
        let pickup = ::CheckPickup.Create(check, thing);
        DEBUG("Original has height=%d radius=%d, new height=%d r=%d",
            thing.height, thing.radius, pickup.height, pickup.radius);
      } else {
        DEBUG("Check %s has already been collected.", check.name);
      }
      ClearPending(check);
      thing.ClearCounters();
      thing.Destroy();
    }
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
      DEBUG("WARN: Closest to %s @ (%f, %f, %f) was %s @ (%f, %f, %f)",
        thing.GetTag(), thing.pos.x, thing.pos.y, thing.pos.z,
        closest.name, closest.pos.x, closest.pos.y, closest.pos.z);
      return closest, min_distance;
    }
    // Not feeling great about this.
    return null, min_distance;
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


  //// Handling for level exit. ////
  // We try to guess if the player reached the exit or left in some other way.
  // In the former case, we give them credit for clearing the level.

  override void WorldUnloaded(WorldEvent evt) {
    DEBUG("PLH WorldUnloaded");
    if (evt.isSaveGame) return;
    if (self.early_exit) return;
    if (level.LevelNum == 0) return;
    if (!apstate.GetRegion(level.MapName)) return;

    ::PlayEventHandler.Get().CheckLocation(
      apstate.GetCurrentRegion().exit_id, string.format("%s - Exit", level.MapName));
  }
}


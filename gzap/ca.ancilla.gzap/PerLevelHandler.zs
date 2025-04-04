// Handler for in-playsim level event stuff.
//
// This is "inside" the playsim, so it gets written to save files and so forth,
// and permits us to persist randomizer state across play sessions.

#namespace GZAP;
#debug off;

const AP_RELEASE_IN_WORLD = 1;
const AP_RELEASE_SECRETS = 2;

class ::PerLevelHandler : EventHandler {
  // Archipelago state manager.
  ::RandoState apstate;
  // Locations that we have yet to resolve when loading into the map. Indexed by apid.
  Map<int, ::Location> pending_locations;
  // Locations corresponding to secret sectors. Indexed by sector number.
  // As we find each one we clear it from the map.
  Map<int, ::Location> secret_locations;
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
    apstate.UpdatePlayerInventory();
  }

  //// Handling for loading into the world. ////
  // For loading save games, WorldThingSpawned doesn't get called, so the PEH
  // will call OnLoadGame() for us.

  override void WorldLoaded(WorldEvent evt) {
    DEBUG("PLH WorldLoaded");

    if ((level.MapName == "GZAPHUB" || level.MapName == "GZAPRST")
         && ::PlayEventHandler.Get().IsRandomized()) {
      Menu.SetMenu("ArchipelagoLevelSelectMenu");
      return;
    }
  }

  void SetupSecrets(::Region region) {
    self.secret_locations.Clear();

    foreach (location : region.locations) {
      if (location.secret_sector < 0) continue;
      if (location.checked) continue;
      DEBUG("Init secret location: %s", location.name);
      let sector = level.sectors[location.secret_sector];
      if (!sector.IsSecret()) {
        // Location isn't marked checked but the corresponding sector has been
        // discovered, so emit a check event for it.
        ::PlayEventHandler.Get().CheckLocation(location.apid, location.name);
      } else {
        // Player hasn't found this yet.
        self.secret_locations.Insert(location.secret_sector, location);
      }
    }
  }

  void UpdateSecrets() {
    foreach (sector_id,location : self.secret_locations) {
      if (!level.sectors[sector_id].IsSecret()) {
        ::PlayEventHandler.Get().CheckLocation(location.apid, location.name);
        // Only process one so we don't modify secret_locations while iterating it.
        self.secret_locations.Remove(sector_id);
        return;
      }
    }
  }

  // Separate functions for handling "new map" and "game loaded" that are actually
  // called from the StaticEventHandler, since it's the only one that can tell
  // the difference.
  void OnNewMap() {
    early_exit = false;
    // No mapinfo -- hopefully this just means it's a TITLEMAP added by a mod or
    // something, and not that we're missing the data package or the player has
    // been changemapping into places they shouldn't be.
    let region = apstate.GetRegion(level.MapName);
    if (!region) return;

    SetupSecrets(region);
    foreach (location : region.locations) {
      // Secret-sector locations are handled by SetupSecrets().
      if (location.secret_sector >= 0) continue;
      DEBUG("Enqueing location: %s", location.name);
      pending_locations.Insert(location.apid, location);
    }
    // Set the timer for how long we'll watch for new things spawning in (from
    // Spawners, scripts, etc) and try to match them to checks.
    alarm = 10;
  }

  void OnLoadGame() {
    early_exit = false;
    // There's a fun edge case here where we load a save game made at the start
    // of the level while the alarm is still counting down. Fortunately this is
    // not actually a problem: this code will get rid of any obsolete already-
    // spawned checks, and WorldThingSpawned will prune newly spawning ones if
    // needed.
    DEBUG("PLH Cleanup");
    apstate.UpdatePlayerInventory();
    let region = apstate.GetRegion(level.MapName);
    if (!region) return;
    SetupSecrets(region);
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
      thing.UpdateFromLocation();
    }
  }

  override void WorldTick() {
    apstate.OnTick();

    if (allow_drops > 0) {
      DEBUG("allow_drops: %d", allow_drops);
      --allow_drops;
    }

    if (level.total_secrets - level.found_secrets != self.secret_locations.CountUsed()) {
      UpdateSecrets();
    }

    if (!alarm) return;
    --alarm;
    if (alarm) return;
    DEBUG("PLH AlarmClockFired");
    foreach (loc : pending_locations) {
      if (loc.checked) continue;
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

  bool IsReplaceable(Actor thing) {
    if (!thing) return false;
    // This also checks the GZAPRC, so if this returns a nonempty category name,
    // it's always eligible even if it would normally be ignored for being non-
    // physical or not an Inventory or what have you.
    let category = ::ScannedItem.ItemCategory(thing);
    if (category != "") return true;

    if (thing.bNOBLOCKMAP || thing.bNOSECTOR || thing.bNOINTERACTION || thing.bISMONSTER) return false;
    if (!(thing is "Inventory")) return false;

    return true;
  }

  override void WorldThingSpawned(WorldEvent evt) {
    let thing = evt.thing;
    if (!IsReplaceable(thing)) return;

    if (alarm) {
      // Start-of-level countdown is still running, see if we need to replace this
      // with an AP check token.
      if (MaybeReplaceWithCheck(thing)) return;
    }

    // It's not a check, and it's not something we need to replace with a check.
    // But, if it's a weapon, we might need to suppress its existence anways.
    if (!ShouldAllow(Weapon(thing))) {
      ReplaceWithAmmo(thing, Weapon(thing));
      thing.ClearCounters();
      thing.Destroy();
    }
  }

  bool MaybeReplaceWithCheck(Actor thing) {
    if (thing is "::CheckPickup") {
      // Check has already been spawned, original item has already been deleted.
      let thing = ::CheckPickup(thing);
      DEBUG("WorldThingSpawned(check) = %s", thing.location.name);
      ClearPending(thing.location);
      return true;
    }

    DEBUG("WorldThingSpawned(%s)", thing.GetTag());
    // Only checks count towards the item tally, not other items.
    thing.ClearCounters();

    let [check, distance] = FindCheckForActor(thing);
    if (check) {
      DEBUG("Replacing %s with %s", thing.GetTag(), check.name);
      let pickup = ::CheckPickup.Create(check, thing);
      DEBUG("Original has height=%d radius=%d, new height=%d r=%d",
          thing.height, thing.radius, pickup.height, pickup.radius);
      ClearPending(check);
      thing.ClearCounters();
      thing.Destroy();
      return true;
    }
    return false;
  }

  // How many tics to allow drops for.
  // We set this to a nonzero value when replicating items so that they don't
  // get culled.
  // This does mean that enemy drops that happen at the same time as replication
  // may get through, but I have yet to come up with a better solution.
  // We could in principle replicate and then hand the spawned item to the handler
  // to say "allow this item, specifically", but that breaks for chains like
  // Shotgun replaced with Spawner which produces ModdedShotgun -- we end up
  // allowing the Spawner but not the ModdedShotgun.
  int allow_drops;
  void AllowDropsBriefly(int tics) { allow_drops = tics; }

  bool ShouldAllow(Weapon thing) {
    if (!thing) return true;
    // What happens outside the randomizer stays outside the randomizer.
    // This includes GZAPHUB and GZAPRST, so the player's starting inventory
    // (including fists/pistol) won't get suppressed on game start.
    if (!apstate.GetCurrentRegion()) return true;
    DEBUG("Checking spawn of %s", thing.GetTag());
    if (self.allow_drops) return true;
    if (ap_suppress_weapon_drops == 0) return true;

    let cls = thing.GetClass();
    if (cls is "WeaponGiver") {
      // WeaponGivers are required to have exactly one DropItem
      cls = thing.GetDropItems().Name;
      if (!cls) return true;
    }

    // Allow only if same slot in inventory
    if (ap_suppress_weapon_drops == 1) {
      // Make the simplifying assumption that all players have the same slots.
      let [assigned,slot,idx] = players[0].weapons.LocateWeapon(cls);
      DEBUG("Checking based on slot: assigned=%d slot=%d", assigned, slot);
      if (!assigned) return true; // I guess???
      return apstate.HasWeaponSlot(slot);
    }

    // Allow only if same weapon in inventory
    if (ap_suppress_weapon_drops == 2) {
      DEBUG("Checking based on class: %s", cls.GetClassName());
      return apstate.HasWeapon(cls.GetClassName());
    }

    DEBUG("Unconditionally blocking spawn.");
    return false;
  }

  void ReplaceWithAmmo(readonly<Actor> spawner, readonly<Weapon> thing) {
    if (!spawner || !thing) return;

    if (thing is "WeaponGiver") {
      string name = thing.GetDropItems().Name;
      Class<Weapon> cls = name;
      if (!cls) return;
      ReplaceWithAmmo(thing, GetDefaultByType(cls));
      return;
    }

    DEBUG("ReplaceWithAmmo: %s", thing.GetTag());
    SpawnAmmo(spawner, thing.AmmoType1, thing.AmmoGive1);
    SpawnAmmo(spawner, thing.AmmoType2, thing.AmmoGive2);
  }

  void SpawnAmmo(readonly<Actor> thing, Class<Ammo> cls, int amount) {
    if (!cls || !amount) return;
    DEBUG("SpawnAmmo: %d of %s", amount, cls.GetClassName());
    let ammo = Inventory(thing.Spawn(cls, thing.pos, ALLOW_REPLACE));
    if (!ammo) return;
    DEBUG("Spawned: %s", ammo.GetTag());
    ammo.ClearCounters();
    ammo.amount = amount;
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
    if (::Location.IsCloseEnough(closest.pos, thing.pos)) {
      DEBUG("WARN: Closest to %s @ (%f, %f, %f) was %s @ (%f, %f, %f)",
        thing.GetTag(), thing.pos.x, thing.pos.y, thing.pos.z,
        closest.name, closest.pos.x, closest.pos.y, closest.pos.z);
      return closest, min_distance;
    }
    // Not feeling great about this.
    return null, min_distance;
  }

  //// Handling for level exit. ////
  // We try to guess if the player reached the exit or left in some other way.
  // In the former case, we give them credit for clearing the level.

  override void WorldUnloaded(WorldEvent evt) {
    DEBUG("PLH WorldUnloaded: save=%d warp=%d lnum=%d", evt.isSaveGame, self.early_exit, level.LevelNum);
    if (evt.isSaveGame || !apstate.GetRegion(level.MapName)) {
      cvar.FindCvar("ap_scan_unreachable").SetInt(0);
      return;
    }

    if (ap_scan_unreachable >= 2) {
      let region = apstate.GetRegion(level.MapName);
      foreach (location : region.locations) {
        if (location.checked) continue;
        DEBUG("Marking %s as unreachable.", location.name);
        ::PlayEventHandler.Get().CheckLocation(location.apid, location.name);
      }
    }
    cvar.FindCvar("ap_scan_unreachable").SetInt(0);

    if (self.early_exit) return;

    ::PlayEventHandler.Get().CheckLocation(
      apstate.GetCurrentRegion().exit_id, string.format("%s - Exit", level.MapName));

    if (ap_release_on_level_clear) {
      let region = apstate.GetRegion(level.MapName);
      foreach (location : region.locations) {
        if (location.checked) continue;
        if (location.secret_sector < 0) {
          if (ap_release_on_level_clear & AP_RELEASE_IN_WORLD == 0) continue;
        } else {
          if (ap_release_on_level_clear & AP_RELEASE_SECRETS == 0) continue;
        }
        DEBUG("Collecting %s on level exit.");
        ::PlayEventHandler.Get().CheckLocation(location.apid, location.name);
      }
    }
  }
}


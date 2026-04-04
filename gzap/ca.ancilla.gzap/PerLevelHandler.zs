// Handler for in-playsim level event stuff.
//
// This is "inside" the playsim, so it gets written to save files and so forth,
// and permits us to persist randomizer state across play sessions.

#namespace GZAP;
#debug off;

#include "./actors/Weapons.zsc"

// Release-on-exit enablement enums
const AP_RELEASE_NEVER = 0;
const AP_RELEASE_IF_KEYS = 1;
const AP_RELEASE_ALWAYS = 2;
// Release-on-exit behaviour bitmask
const AP_RELEASE_OVERT = 1;
const AP_RELEASE_SECRET = 2;

class ::PerLevelHandler : EventHandler {
  // Archipelago state manager.
  ::RandoState apstate;
  // If set, the player is leaving the level via the level select or similar
  // rather than by reaching the exit.
  bool early_exit;
  // Set when the player triggers an exit linedef. If they don't subsequently
  // exit the level, this is probably because they are dead, and will trigger
  // an exit when they respawn.
  bool line_exit_normal;
  bool line_exit_secret;
  // Handling for actor replacement.
  // Disable flag is a countdown timer so we can set it at level load and have
  // it expire automatically.
  // last_replaced lets newly spawned replacement tokens know what they replaced.
  int disable_actor_replacement;
  Class<Actor> last_replaced_actor;

  override void OnRegister() {
    self.disable_actor_replacement = 2;
  }

  static clearscope ::PerLevelHandler Get() {
    return ::PerLevelHandler(Find("::PerLevelHandler"));
  }

  void InitRandoState(bool is_savegame) {
    let datastate = ::RandoState.Get();

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
    // When this happens, our apstate will be whatever was in the savegame, and
    // the datastate will be whatever the game-wide state was just before the
    // game was loaded.
    DEBUG("APState conflict resolution: txn[d]=%d txn[p]=%d",
      ::RandoState.Get().txn, apstate.txn);

    if (self.apstate.txn > datastate.txn) {
      // Our state has a higher txn. This usually means someone started up the
      // game, then loaded a savegame, so we have a fresh apstate in the PEH and
      // the real one in the PLH.
      DEBUG("Using state from playscope.");
      ::PlayEventHandler.Get().apstate = self.apstate;
    } else {
      // PEH state has higher txn. This is usually a result of a savegame being
      // loaded or a return to an earlier level in persistent mode.
      //
      // In the latter case, we want to use the PEH state. In the former case,
      // we want to *mostly* use the PEH state -- in particular we want its
      // record of what checks have been collected and what keys/flags we have
      // -- but we want to rewind our understanding of what items have been
      // *used* to match the loaded save, to avoid a problem where the player
      // saves, picks up a weapon, it vends, and then they load their game and
      // the weapon is gone forever.
      DEBUG("Using state from datascope.");
      if (is_savegame) {
        DEBUG("Restoring items from playscope first.");
        datastate.CopyItemUsesFrom(self.apstate);
        // We also want to use the subregion from the restored state (i.e. our
        // state), since we know that was valid at the position the game was
        // saved in, and any changes to it since should be rolled back.
        if (self.apstate.subregion) {
          datastate.DefineOrActivateSubregion(self.apstate.subregion.name);
        } else {
          datastate.ClearSubregion();
        }
      }
      self.apstate = datastate;
    }
    apstate.UpdatePlayerInventory();
  }

  //// Handling for loading into the world. ////
  // For loading save games, WorldThingSpawned doesn't get called, so the PEH
  // will call OnLoadGame() for us.

  override void WorldLoaded(WorldEvent evt) {
    DEBUG("PLH WorldLoaded");

    if (level.MapName == "GZAPRST") {
      foreach (region : apstate.regions) {
        region.ClearSavedPosition();
      }
    }

    if ((level.MapName == "GZAPHUB" || level.MapName == "GZAPRST")
         && ::PlayEventHandler.Get().IsRandomized()) {
      Menu.SetMenu("ArchipelagoLevelSelectMenu");
      return;
    }
  }

  void SetupSecrets(::Region region) {
    foreach (location : region.locations) {
      location.OnLevelEntry(false);
    }
    DEBUG("Done secret location initialization.");
  }

  void UpdateSecrets() {
    apstate.GetCurrentRegion().CheckEvent("secret", "", null);
  }

  void UpdateCheckPickups() {
    DEBUG("Recomputing item count");
    level.found_items = 0;
    foreach (::CheckPickup thing : ThinkerIterator.Create("::CheckPickup", Thinker.STAT_DEFAULT)) {
      thing.UpdateFromLocation();
      if (thing.GetLocation().checked) level.found_items++;
    }
  }

  // TODO: we should investigate the use of a LevelPostProcessor (https://zdoom.org/wiki/LevelPostProcessor)
  // to place checks on level load. Tricky because anything we place needs an
  // ednum, but we could perhaps use this to remove existing stuff that needs
  // to be replaced and queue up the checks to replace them later?

  // Separate functions for handling "new map" and "game loaded" that are actually
  // called from the StaticEventHandler, since it's the only one that can tell
  // the difference.
  void OnNewMap() {
    DEBUG("PLH OnNewMap");
    InitRandoState(false);
    apstate.ClearSubregion();
    early_exit = false;
    line_exit_normal = false;
    line_exit_secret = false;

    let region = apstate.GetCurrentRegion();
    foreach (location : region.locations) {
      location.OnLevelEntry(true);
    }
    UpdateCheckPickups();
    apstate.UpdatePlayerInventory();

    if (!region.CanAccess()) {
      EventHandler.SendNetworkEvent("ap-level-select", ::Util.HubIndex());
      return;
    }

    // Since this is our first time visiting, we should record our current
    // location as this region's spawnpoint, for fast-travel in hub-logic based
    // wads.
  }

  void OnReopen() {
    DEBUG("PLH OnReopen");
    InitRandoState(false);
    apstate.ClearSubregion();
    early_exit = false;
    line_exit_normal = false;
    line_exit_secret = false;

    let region = apstate.GetCurrentRegion();
    UpdateSecrets();
    UpdateCheckPickups();
    apstate.UpdatePlayerInventory();

    if (!region.CanAccess()) {
      EventHandler.SendNetworkEvent("ap-level-select", ::Util.HubIndex());
      return;
    }

    // Returning to an earlier level, we should teleport the player to the point
    // they were in when they exited it, if we have one recorded.
    // We also need a way to teleport them back to the level entrance...
    if (region.player_position != (0,0,0)) {
      foreach (player : players) {
        if (!player.mo) continue;
        player.mo.SetOrigin(region.player_position, false);
      }
    }
  }

  void OnLoadGame() {
    DEBUG("PLH OnLoadGame");
    InitRandoState(true);
    early_exit = false;
    apstate.UpdatePlayerInventory();

    let region = apstate.GetCurrentRegion();
    SetupSecrets(region);
    UpdateCheckPickups();
  }

  int last_secret;
  override void WorldTick() {
    apstate.OnTick();

    if (disable_actor_replacement > 0) --disable_actor_replacement;

    if (last_secret != level.found_secrets) {
      UpdateSecrets();
      last_secret = level.found_secrets;
    }
  }

  // Handle exit linedef activation.
  // Under normal circumstances, the game handles this on its own and all is well.
  // However, this fails if it's a death exit and the source and destination
  // maps are in the same hubcluster -- which is the case when persistence is on.
  // To handle that case, we record that the line was activated here, and then
  // if the player respawns without leaving the map, we trigger the exit.
  // TODO: investigate if we can use WorldLineActivated, which fires after line
  // activation, instead.
  override void WorldLinePreActivated(WorldEvent evt) {
    let thing = evt.thing;
    let line = evt.ActivatedLine;
    if (!(thing is "PlayerPawn")) return;

    // Key checks are done after WorldLinePreActivated, so we need to check
    // them here just in case that check would normally fail.
    if (!thing.CheckKeys(line.locknumber, false, true)) return;
    if (line.special == 243) { // LS_EXIT_NORMAL
      line_exit_normal = true;
    } else if (line.special == 244) { // LS_EXIT_SECRET
      line_exit_secret = true;
    } else if (line.special == 74) {
      let info = LevelInfo.FindLevelByNum(line.args[0]);
      let region = apstate.GetRegion(info.MapName);
      if (region && !region.CanAccess()) {
        evt.ShouldActivate = false;
      }
    }
  }

  override void PlayerRespawned(PlayerEvent evt) {
    if (line_exit_secret) {
      level.SecretExitLevel(0);
    } else if (line_exit_normal) {
      level.ExitLevel(0, false);
    }
  }

  //// Handling for individual actors spawning in. ////

  override void WorldThingSpawned(WorldEvent evt) {
    let thing = evt.thing;
    if (!thing) return;
    if (!(thing is "::CheckPickup") && thing.bCOUNTITEM) {
      thing.ClearCounters();
    }
  }

  // Special handling for weapons. We use this to replace weapons that we weren't
  // responsible for spawning, so we can decide later if the player is allowed
  // to pick them up.
  override void CheckReplacement(ReplaceEvent evt) {
    if (self.disable_actor_replacement > 0) return;
    // What happens outside the randomizer stays outside the randomizer.
    if (!apstate) return;
    if (!apstate.GetCurrentRegion()) return;

    if (IsAPManagedWeapon(evt.replacee)) {
      self.last_replaced_actor = evt.replacee;
      evt.replacement = "::LockedWeapon";
    }
  }

  bool IsAPManagedWeapon(class<Actor> cls) {
    if (!cls) return false;
    let name = cls.GetClassName();
    let item = self.apstate.FindItem(name);
    if (item) return item.IsWeapon();
    return self.apstate.FindItem("::WeaponGrant_"..name) != null;
  }

  void DisableActorReplacement() { self.disable_actor_replacement = 999; }
  void EnableActorReplacement() { self.disable_actor_replacement = 0; }

  //// Handling for player death. ////
  // At the moment we make no attempt to retrieve the obituary, because GetObituary()
  // returns the *unformatted* version and there doesn't seem to be a ZS-visible
  // way to get the formatted one.

  override void WorldThingDied(WorldEvent evt) {
    let thing = evt.thing;
    if (!thing || !(thing is "PlayerPawn")) return;

    let killer = thing.target;
    if (!killer) {
      ::PlayEventHandler.Get().ReportDeath("died mysteriously");
    } else if (killer == thing) {
      ::PlayEventHandler.Get().ReportDeath("died by misadventure");
    } else {
      ::PlayEventHandler.Get().ReportDeath("killed by " .. killer.GetClassName());
    }
  }

  //// Handling for level exit. ////
  // We try to guess if the player reached the exit or left in some other way.
  // In the former case, we give them credit for clearing the level.

  bool ShouldAutoRelease(::Region region) {
    DEBUG("Should we release %s? enable=%d, keys=%d/%d", region.map, ap_enable_release_on_level_clear, region.KeysFound(), region.KeysTotal());
    if (ap_enable_release_on_level_clear == AP_RELEASE_ALWAYS) {
      return true;
    } else if (ap_enable_release_on_level_clear == AP_RELEASE_IF_KEYS) {
      return region.KeysFound() >= region.KeysTotal();
    } else { // AP_RELEASE_NEVER, or unknown value
      return false;
    }
  }

  bool ShouldAutoReleaseLocation(::Location location) {
    if (location.IsChecked()) return false;
    if (location.IsSecret()) {
      return (ap_release_on_level_clear & AP_RELEASE_SECRET) != 0;
    } else {
      return (ap_release_on_level_clear & AP_RELEASE_OVERT) != 0;
    }
  }

  void OnLevelExit(bool is_save, string next_map) {
    DEBUG("PLH WorldUnloaded: save=%d warp=%d lnum=%d next=%s",
      is_save, self.early_exit, level.LevelNum, next_map);

    let region = apstate.GetRegion(level.MapName);

    if (is_save || !region) {
      cvar.FindCvar("ap_scan_unreachable").SetInt(0);
    }

    if (!region) return;

    // Save the player's location for later restoration on levelport.
    // Only enabled in persistent mode, which uses cluster ID 38281.
    // TODO: make this a flag on the RandoState or PlayEventHandler instead
    // and pass it through in the generated zscript so that there is no chance
    // of a false positive.
    if (self.early_exit && level.cluster == 38281) {
      region.SavePosition(players[0].mo.pos);
    } else {
      region.ClearSavedPosition();
    }

    if (region.hub) {
      // This used to be part of a hubcluster -- this only counts as an exit if
      // we are exiting to another cluster.
      let next_region = apstate.GetRegion(next_map);
      DEBUG("Unloaded in hub: hub=%d, next=%d", region.hub, next_region ? next_region.hub : -1);
      if (next_region && next_region.hub == region.hub) return;
    }

    if (is_save || self.early_exit) return;
    region.CheckEvent("exit", next_map, null);

    if (ap_scan_unreachable >= 2) {
      foreach (location : region.locations) {
        // This will skip collected locations if ap_allow_collect is on.
        // That's intentional, since we don't want the player to accidentally
        // mark as unreachable locations that they skipped because of !collect.
        if (location.IsChecked()) continue;
        DEBUG("Marking %s as unreachable.", location.name);
        ::PlayEventHandler.Get().CheckLocation(location, "map exit, unreachable");
      }
    }
    cvar.FindCvar("ap_scan_unreachable").SetInt(0);

    if (ShouldAutoRelease(region)) {
      DEBUG("AutoRelease enabled");
      foreach (location : region.locations) {
        if (ShouldAutoReleaseLocation(location)) {
          DEBUG("Collecting %s on level exit.", location.name);
          ::PlayEventHandler.Get().CheckLocation(location, "map exit, autorelease", true);
        }
      }
    }
  }
}


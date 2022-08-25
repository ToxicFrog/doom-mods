// Event handler for Gun Bonsai.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.
#namespace TFLV;
#debug off;

class ::EventHandler : StaticEventHandler {
  ::PerPlayerStats playerstats[8];
  ::Upgrade::Registry UPGRADE_REGISTRY;
  ::RC rc;
  ui ::HUD hud;

  override void OnRegister() {
    DEBUG("Initializing Gun Bonsai...");
    // Register all builtin upgrades.
    UPGRADE_REGISTRY = new("::Upgrade::Registry");
    UPGRADE_REGISTRY.RegisterBuiltins();

    if (::Settings.have_legendoom()) {
      console.printf("Legendoom is installed, enabling LD compatibility for Gun Bonsai.");
    } else {
      console.printf("Couldn't find Legendoom, LD-specific features in Gun Bonsai disabled.");
    }

    rc = ::RC.LoadAll("BONSAIRC");
    rc.Finalize(self);
  }

  override void WorldLoaded(WorldEvent evt) {
    DEBUG("WorldLoaded");
    for (uint i = 0; i < 8; ++i) {
      if (playeringame[i]) InitPlayer(i, true);
    }
  }

  override void WorldUnloaded(WorldEvent evt) {
    DEBUG("WorldUnloaded: nextmap=%s", evt.NextMap);
    if (evt.NextMap != "" && !evt.IsSaveGame) return;
    // On world unload for something other than a normal level transition, clear
    // all player info. Either we're about to load a save game (in which case we
    // recover it from the player's inventory) or we're about to start a new game
    // (in which case we should forget everything we know anyways).
    for (uint i = 0; i < 8; ++i) playerstats[i] = null;
  }

  void InitPlayer(uint p, bool new_map=false) {
    PlayerPawn pawn = players[p].mo;
    if (!pawn) return;
    let proxy = ::PerPlayerStatsProxy(pawn.FindInventory("::PerPlayerStatsProxy"));
    if (proxy) {
      // Spawned in player already has stats, those take precedence over whatever
      // we remember.
      DEBUG("Restoring old stats already held by player %d", p);
      playerstats[p] = proxy.stats;
      playerstats[p].Initialize(proxy);
      DEBUG("proxy ring ok: %d", proxy.stats.proxy == proxy);
      DEBUG("stats ring ok: %d", playerstats[p].proxy.stats == playerstats[p]);
      DEBUG("pawn ring ok: %d %d",
        pawn == proxy.owner,
        pawn == proxy.stats.owner);
    } else {
      // Spawned in player doesn't have stats, give them a proxy holding whatever
      // stats we have for them.
      DEBUG("Player %d doesn't have stats, reassigning", p);
      if (!playerstats[p] || (new_map && !::Settings.ignore_death_exits())) {
        // Either we don't have stats for this player, or we do but we're meant
        // to respect death exits; in either case create new stats for them ex
        // nihilo.
        // Note that in the latter case we run this branch only when starting a
        // new map; if the player's inventory has vanished mid-map we make sure
        // to restore the upgrades they already have, for compatibility with mods
        // like Blade of Agony that are constantly taking away your inventory for
        // cutscenes and stuff and then giving it back later.
        DEBUG("No stats recorded in playerstats[%d], starting from scratch", p);
        playerstats[p] = new("::PerPlayerStats");
      }
      proxy = ::PerPlayerStatsProxy(pawn.GiveInventoryType("::PerPlayerStatsProxy"));
      proxy.Initialize(playerstats[p]);
    }
  }

  // Return the stats struct for the consoleplayer, without modifying the playsim.
  // If the stats are missing, null will be returned, and if the playerpawn doesn't
  // have a proxy object or disagrees with the contents of playerstats, too bad.
  // This is used by menu code to get the stats for the player-at-keyboard.
  ui static ::PerPlayerStats GetConsolePlayerStats() {
    return ::EventHandler(StaticEventHandler.Find("::EventHandler")).playerstats[consoleplayer];
  }

  // Get the stats struct for the consoleplayer, resolving any mismatches between
  // the EventHandler's view of things and the PlayerPawn. In particular, if only
  // one of them has the info, that is taken as authoritative and copied to the other;
  // if they both have info but disagree on it, PlayerPawn wins.
  // TODO: some planned upgrades probably need the proxy to be moved to the head
  // of the player's inventory when this happens.
  ::PerPlayerStats GetStatsFor(PlayerPawn pawn) {
    // DEBUG("GetStatsFor: %s", TAG(pawn));
    if (!pawn) return null;
    let stats = playerstats[pawn.PlayerNumber()];
    // If the stats are still attached to the proxy object and the proxy object
    // is still attached to the player, we don't need to rummage through the
    // player's inventory.
    if (stats && stats.proxy && stats.proxy.owner == stats.owner && stats.owner == pawn)
      return stats;
    // Otherwise, something has gone wrong -- either we don't have playerstats
    // recorded here, or they don't match the stats in the player's inventory.
    DEBUG("GetStats: eventhandler/playsim mismatch for player %d", pawn.PlayerNumber());
    InitPlayer(pawn.PlayerNumber());
    return playerstats[pawn.PlayerNumber()];
  }

  ui bool ShouldDrawHUD(uint p) const {
    return playeringame[p]
      && playerstats[p]
      && players[p].ReadyWeapon
      && screenblocks <= 11
      && !automapactive;
  }

  /* ui */ override void RenderOverlay(RenderEvent evt) {
    if (!ShouldDrawHUD(consoleplayer)) return;
    if (!hud) hud = new("::HUD");

    ::CurrentStats stats;
    if (playerstats[consoleplayer].GetCurrentStats(stats))
      hud.Draw(stats);
  }

  void ShowInfo(uint p) {
    // Force info creation
    let stats = playerstats[p];
    if (!stats) {
      console.printf("No info available for player %d", p);
      return;
    }
    // Check for pending level ups and apply those if present.
    if (stats.GetInfoForCurrentWeapon() && stats.GetInfoForCurrentWeapon().StartLevelUp()) return;
    if (stats.StartLevelUp()) return;
    Menu.SetMenu("GunBonsaiStatusDisplay");
    return;
  }

  void ChooseLevelUpOption(uint p, int index) {
    if (!playerstats[p]) return;
    let giver = playerstats[p].currentEffectGiver;
    if (!giver) {
      console.printf("error: bonsai-choose-level-up-option without active level up menu");
      return;
    }
    giver.Choose(index);
  }

  void CycleLDEffect(uint p) {
    if (!playerstats[p]) return;
    let info = playerstats[p].GetInfoForCurrentWeapon();
    if (info) info.ld_info.CycleEffect();
  }

  void SelectLDEffect(uint p, int index) {
    if (!playerstats[p]) return;
    let info = playerstats[p].GetInfoForCurrentWeapon();
    if (info) info.ld_info.SelectEffect(index);
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.player != consoleplayer) {
      return;
    } else if (evt.name == "bonsai-show-info") {
      ShowInfo(evt.player);
    } else if (evt.name == "bonsai-cycle-ld-effect") {
      if (::Settings.have_legendoom()) {
        CycleLDEffect(evt.player);
      } else {
        players[evt.player].mo.A_Log("This feature only works if you also have Legendoom installed.");
      }
    } else if (evt.name == "bonsai-select-effect") {
      SelectLDEffect(evt.player, evt.args[0]);
    } else if (evt.name == "bonsai-choose-level-up-option") {
      ChooseLevelUpOption(evt.player, evt.args[0]);
      // Backwards compatibility with AAS.
      // TODO(0.10.x): remove
      EventHandler.SendNetworkEvent("bonsai_choose_level_up_option");
    } else if (evt.name == "bonsai-toggle-upgrade") {
      // args[0] holds the bag index, args[1] the index of the upgrade within that bag.
      // In the future this might be extended to allow viewing and toggling of upgrades
      // on weapons not presently equipped, but for now [0] is always either 0 (player
      // upgrades) or 1 (currently equipped weapon upgrades).
      let stats = playerstats[evt.player];
      DEBUG("toggle: %d %d", evt.args[0], evt.args[1]);
      ::Upgrade::BaseUpgrade upgrade;
      if (evt.args[0] == 0) {
        DEBUG("player has upgrades: %d", stats.upgrades != null);
        upgrade = stats.upgrades.upgrades[evt.args[1]];
      } else {
        DEBUG("weapon has upgrades: %d", stats.GetInfoForCurrentWeapon().upgrades != null);
        upgrade = stats.GetInfoForCurrentWeapon().upgrades.upgrades[evt.args[1]];
      }
      upgrade.enabled = !upgrade.enabled;
    } else if (evt.name.IndexOf("bonsai-debug") == 0) {
      ::Debug.DebugCommand(players[evt.player].mo, evt.name, evt.args[0]);
    }
  }

  override void WorldThingDamaged(WorldEvent evt) {
    DEBUG("WTD: %s inflictor=%s source=%s damage=%d type=%s flags=%X, hp=%d",
      TAG(evt.thing), TAG(evt.inflictor), TAG(evt.damagesource),
      evt.damage, evt.damagetype, evt.damageflags, evt.thing.health);
    if (evt.damagesource == players[consoleplayer].mo
        && evt.thing.bISMONSTER
        && !evt.thing.bFRIENDLY // do not award XP or trigger procs when attacking friendlies
        && evt.thing != evt.damagesource
        && evt.damage > 0) {
      let stats = ::PerPlayerStats.GetStatsFor(PlayerPawn(evt.damagesource));
      stats.OnDamageDealt(evt.inflictor, evt.thing, evt.damage);
      if (evt.thing.health <= 0) {
        stats.OnKill(evt.inflictor, evt.thing);
      }
    } else if (evt.thing == players[consoleplayer].mo) {
      ::PerPlayerStats.GetStatsFor(PlayerPawn(evt.thing)).OnDamageReceived(
        evt.inflictor, evt.damagesource, evt.damage);
    }
  }

  override void WorldThingSpawned(WorldEvent evt) {
    Actor thing = evt.thing;
    if (thing.bMISSILE && thing.target == players[consoleplayer].mo) {
      // If it's a projectile (MISSILE flag is set) and target=player, the player
      // just fired a shot. This is our chance to fiddle with its flags and whatnot.
      ::PerPlayerStats.GetStatsFor(thing.target).OnProjectileCreated(thing);
    }

    // DEBUG("WTS: %s (owner=NONE) (master=%s) (target=%s) (tracer=%s)",
    //   thing.GetClassName(),
    //   TAG(thing.master),
    //   TAG(thing.target),
    //   TAG(thing.tracer));
  }
}

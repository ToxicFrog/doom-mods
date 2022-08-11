// Event handler for Gun Bonsai.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.
#namespace TFLV;
#debug off

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

  override void WorldUnloaded(WorldEvent evt) {
    DEBUG("WorldUnloaded: nextmap=%s", evt.NextMap);
    if (evt.NextMap != "" && !evt.IsSaveGame) return;
    // On world unload for something other than a normal level transition, clear
    // all player info. Either we're about to load a save game (in which case we
    // recover it from the player's inventory) or we're about to start a new game
    // (in which case we should forget everything we know anyways).
    for (uint i = 0; i < 8; ++i) playerstats[i] = null;
  }

  override void PlayerEntered(PlayerEvent evt) {
    DEBUG("PlayerEntered");
    let p = evt.PlayerNumber;
    PlayerPawn pawn = players[p].mo;
    if (!pawn) return;
    let proxy = ::PerPlayerStatsProxy(pawn.FindInventory("::PerPlayerStatsProxy"));
    if (proxy) {
      // Spawned in player already has stats, those take precedence over whatever
      // we remember.
      DEBUG("Restoring old stats already held by player %d", p);
      playerstats[p] = proxy.stats;
    } else {
      // Spawned in player doesn't have stats, give them a proxy holding whatever
      // stats we have for them.
      DEBUG("Player %d doesn't have stats, reassigning", p);
      if (!playerstats[p] || !::Settings.ignore_death_exits()) {
        // Either we don't have stats for this player, or we do but we're meant
        // to respect death exits; in either case create new stats for them ex
        // nihilo.
        DEBUG("No stats recorded in playerstats[%d], starting from scratch", p);
        playerstats[p] = new("::PerPlayerStats");
      }
      proxy = ::PerPlayerStatsProxy(pawn.GiveInventoryType("::PerPlayerStatsProxy"));
      proxy.Initialize(playerstats[p]);
    }
  }

  ui bool ShouldDrawHUD(PlayerPawn pawn) const {
    return pawn
      && players[consoleplayer].ReadyWeapon
      && screenblocks <= 11
      && !automapactive;
  }

  override void RenderUnderlay(RenderEvent evt) {
    PlayerPawn pawn = players[consoleplayer].mo;
    if (!ShouldDrawHUD(pawn)) return;
    if (!hud) hud = new("::HUD");

    // Not sure how this can happen, seems to be associated with certain kinds
    // of player death.
    ::PerPlayerStats ppstats = ::PerPlayerStats.GetStatsFor(pawn);
    if (!ppstats) return;

    ::CurrentStats stats;
    if (ppstats.GetCurrentStats(stats))
      hud.Draw(stats);
  }

  void ShowInfo(PlayerPawn pawn) {
    ::PerPlayerStats stats = ::PerPlayerStats.GetStatsFor(pawn);
    // Check for pending level ups and apply those if present.
    if (stats.GetInfoForCurrentWeapon().StartLevelUp()) return;
    if (stats.StartLevelUp()) return;
    Menu.SetMenu("GunBonsaiStatusDisplay");
    return;
  }

  void ShowInfoConsole(PlayerPawn pawn) {
    ::CurrentStats stats;
    if (!::PerPlayerStats.GetStatsFor(pawn).GetCurrentStats(stats)) return;
    console.printf("Player:\n    Level %d (%d/%d XP)",
      stats.plvl, stats.pxp, stats.pmax);
    stats.pupgrades.DumpToConsole("    ");
    console.printf("%s:\n    Level %d (%d/%d XP)",
      stats.wname, stats.wlvl, stats.wxp, stats.wmax);
    console.printf("    Hitscan: %d\n    Projectile: %d\n",
      stats.winfo.hitscan_shots, stats.winfo.projectile_shots);
    stats.wupgrades.DumpToConsole("    ");
    stats.winfo.ld_info.DumpToConsole();
  }

  play void CycleLDEffect(PlayerPawn pawn) {
    let info = ::PerPlayerStats.GetStatsFor(pawn).GetInfoForCurrentWeapon();
    if (info) info.ld_info.CycleEffect();
  }

  void ChooseLevelUpOption(PlayerPawn pawn, int index) {
    let stats = ::PerPlayerStats.GetStatsFor(pawn);
    let giver = stats.currentEffectGiver;
    if (!giver) {
      console.printf("error: bonsai_choose_level_up_option without active level up menu");
      return;
    }
    giver.Choose(index);
  }

  // TODO: replace GetStatsFor (here and elsewhere) with direct reads of the
  // playerstats array.
  play void SelectLDEffect(PlayerPawn pawn, int index) {
    let info = ::PerPlayerStats.GetStatsFor(pawn).GetInfoForCurrentWeapon();
    if (info) info.ld_info.SelectEffect(index);
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.player != consoleplayer) {
      return;
    } else if (evt.name == "bonsai_show_info") {
      ShowInfo(players[evt.player].mo);
    } else if (evt.name == "bonsai_show_info_console") {
      ShowInfoConsole(players[evt.player].mo);
    } else if (evt.name == "bonsai_cycle_ld_effect") {
      if (::Settings.have_legendoom()) {
        CycleLDEffect(players[evt.player].mo);
      } else {
        players[evt.player].mo.A_Log("This feature only works if you also have Legendoom installed.");
      }
    } else if (evt.name == "bonsai_select_effect") {
      SelectLDEffect(players[evt.player].mo, evt.args[0]);
    } else if (evt.name == "bonsai_choose_level_up_option") {
      ChooseLevelUpOption(players[evt.player].mo, evt.args[0]);
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

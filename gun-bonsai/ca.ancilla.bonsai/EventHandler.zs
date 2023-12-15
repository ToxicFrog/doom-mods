// Event handler for Gun Bonsai.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.
#namespace TFLV;
#debug off;

class ::EventHandler : StaticEventHandler {
  ::PerPlayerStats playerstats[MAXPLAYERS];
  ::Upgrade::Registry UPGRADE_REGISTRY;
  ::RC rc;
  ui ::HUD hud;

  override void OnRegister() {
    console.printf("Initializing Gun Bonsai v%s...", MOD_VERSION());
    UPGRADE_REGISTRY = new("::Upgrade::Registry");

    if (::Settings.have_legendoom()) {
      console.printf("%s", StringTable.Localize("$TFLV_MSG_LD_YES"));
    } else {
      console.printf("%s", StringTable.Localize("$TFLV_MSG_LD_NO"));
    }

    rc = ::RC.LoadAll("BONSAIRC");
    rc.Finalize(self);
  }

  override void WorldLoaded(WorldEvent evt) {
    if (level.totaltime == 0) {
      // Starting a new game? Clear all info.
      for (uint i = 0; i < MAXPLAYERS; ++i) playerstats[i] = null;
    }
    for (uint i = 0; i < MAXPLAYERS; ++i) {
      if (playeringame[i]) InitPlayer(i, true);
    }
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
      if (!playerstats[p] || (new_map && !bonsai_ignore_death_exits)) {
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
      console.printf(StringTable.Localize("$TFLV_MSG_PLAYERSTATS_MISSING"), p);
      return;
    }
    // Check for pending level ups and apply those if present.
    if (stats.GetInfoForCurrentWeapon() && stats.GetInfoForCurrentWeapon().StartLevelUp()) return;
    if (stats.StartLevelUp()) return;
    if (p == consoleplayer) Menu.SetMenu("GunBonsaiStatusDisplay");
    return;
  }

  void ChooseLevelUpOption(uint p, int index) {
    if (!playerstats[p]) return;
    let giver = playerstats[p].currentEffectGiver;
    if (!giver) {
      // They chose a level up but their effectgiver is missing! This probably means
      // that something ate their inventory between them opening the menu and choosing
      // an option.
      DEBUG("Stats for player %d have id %d and no effect giver", p, playerstats[p].id);
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
    if (evt.name == "bonsai-show-info") {
      ShowInfo(evt.player);
    } else if (evt.name == "bonsai-cycle-ld-effect") {
      if (::Settings.have_legendoom()) {
        CycleLDEffect(evt.player);
      } else {
        players[evt.player].mo.A_Log(StringTable.Localize("$TFLV_MSG_LD_REQUIRED"));
      }
    } else if (evt.name == "bonsai-select-effect") {
      if (::Settings.have_legendoom()) {
        SelectLDEffect(evt.player, evt.args[0]);
      } else {
        players[evt.player].mo.A_Log(StringTable.Localize("$TFLV_MSG_LD_REQUIRED"));
      }
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
        stats.ToggleUpgrade(evt.args[1]);
      } else {
        DEBUG("weapon has upgrades: %d", stats.GetInfoForCurrentWeapon().upgrades != null);
        stats.GetInfoForCurrentWeapon().ToggleUpgrade(evt.args[1]);
      }
    } else if (evt.name.IndexOf("bonsai-debug") == 0) {
      ::Debug.DebugCommand(players[evt.player].mo, evt.name, evt.args[0]);
    }
  }

  static PlayerPawn GetPlayerDamageSource(WorldEvent evt) {
    if (evt.damage <= 0
        || !evt.thing.bISMONSTER
        || !evt.damagesource
        || evt.thing.bFRIENDLY
        || evt.thing == evt.damagesource) {
      // Don't trigger on non-damaging "attacks", attacks against things that
      // aren't monsters, attacks on friendlies, or self-damage.
      return null;
    }
    // If the damage source is a player, we're good to go.
    if (evt.damagesource is "PlayerPawn") return PlayerPawn(evt.damagesource);
    // If the damage source has a FriendPlayer defined, attribute the damage to
    // them instead of the real source. Subtract 1 because FriendPlayer is 1-indexed.
    if (evt.damagesource.FriendPlayer && playeringame[evt.damagesource.FriendPlayer-1])
      return players[evt.damagesource.FriendPlayer-1].mo;
    //
    return null;
  }

  override void WorldThingDamaged(WorldEvent evt) {
    DEBUG("WTD: %s inflictor=%s source=%s damage=%d type=%s flags=%X, hp=%d",
      TAG(evt.thing), TAG(evt.inflictor), TAG(evt.damagesource),
      evt.damage, evt.damagetype, evt.damageflags, evt.thing.health);

    // Player taking damage from something.
    // Note that this triggers even on self-damage, which is what allows upgrades
    // like Blast Shaping to work.
    if (PlayerPawn(evt.thing)) {
      ::PerPlayerStats.GetStatsFor(PlayerPawn(evt.thing)).OnDamageReceived(
        evt.inflictor, evt.damagesource, evt.damage);
      return;
    }

    // Player damaging something. This does not trigger on self-damage (c.f.
    // GetPlayerDamageSource()) so you don't end up applying dots to yourself
    // or exploding or something.
    PlayerPawn source = GetPlayerDamageSource(evt);
    if (source) {
      let stats = ::PerPlayerStats.GetStatsFor(PlayerPawn(source));
      stats.OnDamageDealt(evt.inflictor, evt.thing, evt.damage);
      if (evt.thing.health <= 0) {
        stats.OnKill(evt.inflictor, evt.thing);
      }
      return;
    }
  }

  override void WorldThingSpawned(WorldEvent evt) {
    Actor thing = evt.thing;
    if (!thing) return;
    if (thing.bMISSILE && PlayerPawn(thing.target)) {
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

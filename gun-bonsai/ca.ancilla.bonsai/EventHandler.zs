// Event handler for Gun Bonsai.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.
#namespace TFLV;
#debug off;

class ::EventHandler : StaticEventHandler {
  ::PerPlayerStats playerstats[MAXPLAYERS];
  ::Upgrade::Registry UPGRADE_REGISTRY;
  ::RC rc;
  ::GunBonsaiService service;
  ui ::HUD hud;

  override void OnRegister() {
    console.printf("Initializing Gun Bonsai v%s...", MOD_VERSION());
    UPGRADE_REGISTRY = new("::Upgrade::Registry");
    rc = ::RC.LoadAll("BONSAIRC");
    rc.Finalize(self);

    let service = ::GunBonsaiService(ServiceIterator.Find("::GunBonsaiService").Next());
    service.Init(self);
    self.service = service;
  }

  int mapnum;
  override void WorldLoaded(WorldEvent evt) {
    if (level.totaltime == 0) {
      // Starting a new game? Clear all info.
      for (uint i = 0; i < MAXPLAYERS; ++i) playerstats[i] = null;
    }
    for (uint i = 0; i < MAXPLAYERS; ++i) {
      if (playeringame[i]) InitPlayer(i, true);
    }
    if (!evt.IsSaveGame && !evt.IsReopen) {
      console.printf("New level: %d [%d/%d]", mapnum, level.MapTime, level.Time);
      for (uint i = 0; i < 8; ++i) {
        // Report to all players that they have entered a new level.
        // Note that MAP01 is levelnum=0; for linear games mapnum is thus the
        // number of maps *cleared*. It gets weird for hubbed games like Hexen,
        // it basically becomes the number of maps you have visited at least once
        // minus one.
        if (playeringame[i] && playerstats[i]) {
          playerstats[i].OnMapEntry(level.mapname, mapnum);
        }
      }
      ++mapnum;
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

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.name == "bonsai-show-info") {
      ShowInfo(evt.player);
    } else if (evt.name == "bonsai-choose-level-up-option") {
      ChooseLevelUpOption(evt.player, evt.args[0]);
    } else if (evt.name == "bonsai-toggle-upgrade") {
      // args[0] holds the bag index, args[1] the index of the upgrade within that bag.
      // In the future this might be extended to allow viewing and toggling of upgrades
      // on weapons not presently equipped, but for now [0] is always either 0 (player
      // upgrades) or 1 (currently equipped weapon upgrades).
      ToggleUpgrade(evt.player, evt.args[0] != 0, evt.args[1]);
    } else if (evt.name == "bonsai-tune-upgrade") {
      // Same as above, except that args[2] holds the amount to tune by, which
      // may be negative.
      TuneUpgrade(evt.player, evt.args[0] != 0, evt.args[1], evt.args[2]);
    } else if (evt.name.IndexOf("bonsai-debug") == 0) {
      ::Debug.DebugCommand(service, evt.player, evt.name, evt.args[0]);
    }
  }

  void ToggleUpgrade(int player, bool on_weapon, int index) {
    let stats = playerstats[player];
    DEBUG("toggle: %d %d", on_weapon, index);
    // ::Upgrade::BaseUpgrade upgrade;
    if (on_weapon) {
      DEBUG("weapon has upgrades: %d", stats.GetInfoForCurrentWeapon().upgrades != null);
      stats.GetInfoForCurrentWeapon().ToggleUpgrade(index);
    } else {
      DEBUG("player has upgrades: %d", stats.upgrades != null);
      stats.ToggleUpgrade(index);
    }
  }

  void TuneUpgrade(int player, bool on_weapon, int index, int amount) {
    let stats = playerstats[player];
    DEBUG("tune: %d %d %d", on_weapon, index, amount);
    // ::Upgrade::BaseUpgrade upgrade;
    if (on_weapon) {
      stats.GetInfoForCurrentWeapon().TuneUpgrade(index, amount);
    } else {
      stats.TuneUpgrade(index, amount);
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

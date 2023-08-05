// Event handler for Laevis.
// Handles giving the player a tracking item when they spawn in, which holds
// their LD upgrade library.
// This code is largely a stripped-down version of the event handler from Gun
// Bonsai.
#namespace TFLV;
#debug off;

class ::EventHandler : StaticEventHandler {
  ::PerPlayerStats playerstats[8];

  override void OnRegister() {
    console.printf("Initializing Laevis v%s...", MOD_VERSION());
  }

  override void WorldLoaded(WorldEvent evt) {
    if (level.totaltime == 0) {
      // Starting a new game? Clear all info.
      for (uint i = 0; i < 8; ++i) playerstats[i] = null;
    }
    for (uint i = 0; i < 8; ++i) {
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
      if (!playerstats[p] || (new_map && !laevis_ignore_death_exits)) {
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
    // if (!ShouldDrawHUD(consoleplayer)) return;
    // if (!hud) hud = new("::HUD");

    // ::CurrentStats stats;
    // if (playerstats[consoleplayer].GetCurrentStats(stats))
    //   hud.Draw(stats);
  }

  void ShowInfo(uint p) {
    // Force info creation
    let stats = playerstats[p];
    if (!stats) {
      console.printf(StringTable.Localize("$TFLV_MSG_PLAYERSTATS_MISSING"), p);
      return;
    }
    if (p == consoleplayer) Menu.SetMenu("LaevisStatusDisplay");
    return;
  }

  void ChooseLevelUpOption(uint p, int index) {
    if (!playerstats[p]) return;
    // player should be in the middle of picking up a new LD weapon; pick an
    // upgrade to discard.
  }

  void CycleLDEffect(uint p) {
    if (!playerstats[p]) return;
    let info = playerstats[p].GetInfoForCurrentWeapon();
    if (info) info.CycleEffect();
  }

  void SelectLDEffect(uint p, int index) {
    if (!playerstats[p]) return;
    let info = playerstats[p].GetInfoForCurrentWeapon();
    if (info) info.SelectEffect(index);
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.name == "laevis-show-info") {
      ShowInfo(evt.player);
    } else if (evt.name == "laevis-cycle-ld-effect") {
      CycleLDEffect(evt.player);
    } else if (evt.name == "laevis-select-effect") {
      SelectLDEffect(evt.player, evt.args[0]);
    } else if (evt.name == "laevis-choose-level-up-option") {
      ChooseLevelUpOption(evt.player, evt.args[0]);
    }
  }

  override void WorldThingSpawned(WorldEvent evt) {
    Actor thing = evt.thing;
    if (!thing) return;
    if (thing is "LDWeaponPickup" || thing is "LDLegendaryCommonPickupEffect") {
      thing.height = 24;
      thing.A_SpriteOffset(0, -8);
      // thing.bFLOATBOB = true;
      // thing.bNOGRAVITY = true;
    }
  }
}

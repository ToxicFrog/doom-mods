#namespace TFIS;
#debug off;

class ::IndestructableEventHandler : StaticEventHandler {
  ::PlayerInfo info[MAXPLAYERS];

  // Behaviour here is largely copied from Gun Bonsai.
  // This is called on every player in the game whenever a level is loaded.
  void InitPlayer(uint p) {
    DEBUG("Initializing player[%d]", p);
    let pawn = players[p].mo;
    let force = ::IndestructableForce(pawn.FindInventory("::IndestructableForce"));
    if (force) {
      // Player is already set up? Nothing to do.
      if (force.info && force.info == info[p]) {
        DEBUG("player is already set up");
        return;
      }

      // Player has a force, but it doesn't match what we have; probably we just
      // loaded a savegame. Force takes precedence, throw away whatever the
      // event handler has.
      DEBUG("actor state takes precedence");
      info[p] = force.info;
      force.Initialize(force.info);

    } else if (!info[p] || !indestructable_ignore_death_exits) {
      DEBUG("no actor state and no usable stored info, doing from-scratch initialization");
      // Player doesn't have a force and we either don't have anything stored
      // for them, or are meant to pretend we don't. Set them up from scratch.
      force = ::IndestructableForce(pawn.GiveInventoryType("::IndestructableForce"));
      force.Initialize(::PlayerInfo.Create());
      info[p] = force.info;

    } else {
      DEBUG("no actor state, restoring stored info");
      // Player doesn't have a force, we do remember data from them and are
      // allowed to use it.
      force = ::IndestructableForce(pawn.GiveInventoryType("::IndestructableForce"));
      force.Initialize(info[p]);
    }
  }

  // Called when a player "enters the game", after their corresponding Actor is
  // initialized, and before WorldLoaded is called. This is called on new games
  // and "normal" level transitions, but not when loading a savegame.
  override void PlayerEntered(PlayerEvent evt) {
    DEBUG("PlayerEntered: %d %d", evt.playernumber, players[evt.playernumber].mo != null);
    if (level.totaltime == 0) {
      // New game. Clear our saved info. The player shouldn't have any info either,
      // so this will result in them being set up from scratch.
      info[evt.playernumber] = null;
    }
    InitPlayer(evt.playernumber);
  }

  // Called when world loading is complete, just before the first tic runs. This
  // happens after PlayerEntered for all players.
  // Unlike PlayerEntered, this is called when loading a savegame, so we try to
  // initialize everyone here to handle the savegame case.
  override void WorldLoaded(WorldEvent evt) {
    DEBUG("WorldLoaded: t=%d", level.totaltime);
    for (uint i = 0; i < MAXPLAYERS; ++i) {
      if (playeringame[i]) {
        InitPlayer(i);
      }
    }
  }

  override void WorldUnloaded(WorldEvent evt) {
    // Don't do anything if we're unloading this to load a savegame or quit.
    if (indestructable_gun_bonsai_mode) return;
    if (evt.isSaveGame || !evt.nextMap) return;

    for (uint i = 0; i < 8; ++i) {
      if (!playeringame[i]) continue;
      // We trust the PlayerInfo not to twice-count here.
      info[i].AddLevelClearLives(level.GetChecksum());
    }
  }

  override void WorldThingDamaged(WorldEvent evt) {
    if (indestructable_gun_bonsai_mode) return;
    if (!evt.thing || !evt.damagesource || !evt.thing.bBOSS || evt.thing.health > 0) return;
    let lives = indestructable_lives_per_boss;
    if (!lives) return;
    let pawn = PlayerPawn(evt.damagesource);
    if (!pawn) return;
    let force = ::IndestructableForce(pawn.FindInventory("::IndestructableForce"));
    if (!force) return; // PANIC
    force.info.AddBossKillLives();
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.player != consoleplayer) {
      return;
    } else if (evt.name == "indestructable-adjust-lives") {
      info[evt.player].AdjustLives(evt.args[0], evt.args[1] != 0);
    } else if (evt.name == "indestructable-clamp-lives") {
      let min_lives = evt.args[0];
      let max_lives = evt.args[1];
      let pinfo = info[evt.player];

      if (min_lives >= 0) pinfo.lives = max(min_lives, pinfo.lives);
      if (max_lives >= 0) pinfo.lives = min(max_lives, pinfo.lives);
      info[evt.player].AdjustLives(0, false);
    } else if (evt.name == "indestructable-set-lives") {
      info[evt.player].lives = evt.args[0] < 0 ? -1 : evt.args[0];
      info[evt.player].AdjustLives(0, false);
    }
  }
}

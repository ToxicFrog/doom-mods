#namespace TFIS;
#debug off;

class ::IndestructableEventHandler : StaticEventHandler {
  ::PlayerInfo info[MAXPLAYERS];

  // Behaviour here is largely copied from Gun Bonsai.
  // This is called on every player in the game whenever a level is loaded.
  void InitPlayer(uint p) {
    DEBUG("get player");
    let pawn = players[p].mo;
    DEBUG("get force");
    let force = ::IndestructableForce(pawn.FindInventory("::IndestructableForce"));
    if (force) {
      DEBUG("initplayer fastpath?");
      // Player is already set up? Nothing to do.
      if (force.info && force.info == info[p]) return;

      // Player has a force, but it doesn't match what we have; probably we just
      // loaded a savegame. Force takes precedence, throw away whatever the
      // event handler has.
      DEBUG("force takes precedence");
      info[p] = force.info;
      force.Initialize(force.info);

    } else if (!info[p] || !indestructable_ignore_death_exits) {
      DEBUG("reinitializing");
      // Player doesn't have a force and we either don't have anything stored
      // for them, or are meant to pretend we don't. Set them up from scratch.
      force = ::IndestructableForce(pawn.GiveInventoryType("::IndestructableForce"));
      DEBUG("done give, calling initialize");
      force.Initialize(::PlayerInfo.Create());
      info[p] = force.info;

    } else {
      DEBUG("assuming direct control, info");
      // Player doesn't have a force, we do remember data from them and are
      // allowed to use it.
      force = ::IndestructableForce(pawn.GiveInventoryType("::IndestructableForce"));
      force.Initialize(info[p]);
    }
    DEBUG("initialization complete");
  }

  override void WorldLoaded(WorldEvent evt) {
    DEBUG("WorldLoaded");
    if (level.totaltime == 0) {
      DEBUG("Clearing all info");
      // Starting a new game? Clear all info.
      for (uint i = 0; i < MAXPLAYERS; ++i) info[i] = null;
    }

    for (uint i = 0; i < MAXPLAYERS; ++i) {
      if (!playeringame[i]) continue;
      DEBUG("Initializing player[%d]", i);
      InitPlayer(i);
      // Don't give the player per-level lives when loading an earlier save or
      // returning to a hubmap or starting a new game.
      if (evt.isSaveGame || evt.isReopen || level.totaltime == 0) continue;
      info[i].AddLevelStartLives();
    }
    DEBUG("world load complete");
  }

  override void WorldThingDamaged(WorldEvent evt) {
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
    } else if (evt.name == "indestructable_adjust_lives") {
      let pawn = players[evt.player].mo;
      let force = ::IndestructableForce(pawn.FindInventory("::IndestructableForce"));
      if (!force) return;
      force.info.AdjustLives(evt.args[0], evt.args[1], evt.args[2]);
    }
  }
}

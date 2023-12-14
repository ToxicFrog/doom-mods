#namespace TFIS;
#debug off;

class ::IndestructableEventHandler : StaticEventHandler {
  // Initialize a player by giving them the IndestructableForce. Returns false if
  // the player was already inited and true if they're new.
  bool InitPlayer(PlayerPawn pawn) {
    let force = ::IndestructableForce(pawn.GiveInventoryType("::IndestructableForce"));
    if (!force) return false; // Either we couldn't give it or they already have one
    // We gave them a new one, so give them the starting number of lives.
    force.Initialize(::PlayerInfo.Create());
    return true;
  }

  override void WorldLoaded(WorldEvent evt) {
    // Don't trigger on game loads or returns to hub levels.
    if (evt.IsSaveGame || evt.IsReopen) return;

    // Make sure all the players have a force.
    for (uint i = 0; i < 8; ++i) {
      if (!playeringame[i]) continue;
      let pawn = players[i].mo;
      if (InitPlayer(pawn)) continue; // don't apply start-of-level modifiers when starting a new game
      let force = ::IndestructableForce(pawn.FindInventory("::IndestructableForce"));
      if (!force) continue; // should never happen
      force.info.AddLevelStartLives();
    }
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

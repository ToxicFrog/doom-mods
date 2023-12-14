#namespace TFIS;
#debug off;

class ::IndestructableEventHandler : StaticEventHandler {
  // The IndestructableForce does all the work in AbsorbDamage, since that's the
  // last event handler called before the engine decides if the player is dead
  // or not. However, in order to make sure that it sees the true damage that's
  // about to be dealt, after protection powers, armour, etc have all processed
  // it, we need to make sure it's at the end of the inventory chain. Items are
  // always inserted in head position and the player's starting inventory usually
  // includes armour, so there's a good chance that during initialization, we
  // are not in tail position and there's armour after us. On the plus side, this
  // means that once we move to tail position, we should stay there.
  static void MoveToTail(Actor owner, ::IndestructableForce force) {
    Actor head, tail;
    while (owner) {
      DEBUG("MoveToTail: inspecting %s", TAG(owner));
      if (owner.inv == force) head = owner;
      if (owner.inv == null) tail = owner;
      owner = owner.inv;
    }
    DEBUG("MoveToTail: head=%s, tail=%s", TAG(head), TAG(tail));
    if (tail == force) return;
    head.inv = force.inv;
    tail.inv = force;
    force.inv = null;
    DEBUG("MoveToTail: head %s; head> %s; tail %s; tail> %s; force> %s",
      TAG(head), TAG(head.inv), TAG(tail), TAG(tail.inv), TAG(force.inv));
  }

  // Initialize a player by giving them the IndestructableForce. Returns false if
  // the player was already inited and true if they're new.
  bool InitPlayer(PlayerPawn pawn) {
    let force = ::IndestructableForce(pawn.GiveInventoryType("::IndestructableForce"));
    if (!force) return false; // Either we couldn't give it or they already have one
    // We gave them a new one, so give them the starting number of lives.
    force.lives = ::Util.GetInt("indestructable_starting_lives");
    force.delta_since_report = force.lives;
    force.ReportLivesCount(force.lives);
    MoveToTail(pawn, force);
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
      force.AddLevelStartLives();
    }
  }

  override void WorldThingDamaged(WorldEvent evt) {
    if (!evt.thing || !evt.damagesource || !evt.thing.bBOSS || evt.thing.health > 0) return;
    let lives = ::Util.GetInt("indestructable_lives_per_boss");
    if (!lives) return;
    let pawn = PlayerPawn(evt.damagesource);
    if (!pawn) return;
    let force = ::IndestructableForce(pawn.FindInventory("::IndestructableForce"));
    if (!force) return; // PANIC
    force.AddBossKillLives();
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.player != consoleplayer) {
      return;
    } else if (evt.name == "indestructable_adjust_lives") {
      let pawn = players[evt.player].mo;
      let force = ::IndestructableForce(pawn.FindInventory("::IndestructableForce"));
      if (!force) return;
      force.AdjustLives(evt.args[0], evt.args[1], evt.args[2]);
    }
  }
}

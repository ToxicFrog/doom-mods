#namespace TFIS;

class ::IndestructableEventHandler : StaticEventHandler {
  static int GetInt(string name) {
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetInt();
    return -1;
  }

  static bool GetBool(string name){
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetBool();
    return false;
  }

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
      if (owner.inv == force) head = owner;
      if (owner.inv == null) tail = owner;
      owner = owner.inv;
    }
    head.inv = force.inv;
    tail.inv = force;
    force.inv = null;
  }

  override void PlayerSpawned(PlayerEvent evt) {
    PlayerPawn pawn = players[evt.playerNumber].mo;
    if (!pawn) return;

    let force = ::IndestructableForce(pawn.GiveInventoryType("::IndestructableForce"));
    if (!force) return; // Either we couldn't give it or they already have one
    // We gave them a new one, so give them the starting number of lives.
    force.lives = GetInt("indestructable_starting_lives");
  }

  override void WorldLoaded(WorldEvent evt) {
    // Don't trigger on game loads or returns to hub levels.
    if (evt.IsSaveGame || evt.IsReopen) return;
    // New level? Refill their lives.
    // PlayerSpawned runs first, so they should already have the force.
    let pawn = players[consoleplayer].mo;
    let force = ::IndestructableForce(pawn.FindInventory("::IndestructableForce"));

    if (!force) return; // PANIC
    MoveToTail(pawn, force);
    force.lives = max(force.lives, GetInt("indestructable_lives_after_level"));
    console.printf("You have \c[GOLD]%d\c- extra %s!",
      force.lives, force.lives == 1 ? "life" : "lives");
  }

  override void WorldThingDied(WorldEvent evt) {
    if (!evt.thing.bBOSS || !evt.inflictor) return;
    let lives = GetInt("indestructable_lives_per_boss");
    if (!lives) return;
    let pawn = PlayerPawn(evt.inflictor.target);
    if (!pawn) return;
    let force = ::IndestructableForce(pawn.FindInventory("::IndestructableForce"));
    if (!force) return; // PANIC
    force.lives += lives;
    console.printf("Absorbed the boss's power! You now have \c[CYAN]%d\c- extra %s!",
      force.lives, force.lives == 1 ? "life" : "lives");
  }
}

class ::IndestructableForce : Inventory {
  int lives;
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INVENTORY.IGNORESKILL;
    +INVENTORY.UNTOSSABLE;
    +INVENTORY.UNDROPPABLE;
    +INVENTORY.QUIET;
  }

  States {
    RestoreHealth:
      TNT1 A 1;
      // We delay this by a tic after activating the powerup because if we try
      // to zero out the damage, the player doesn't get knocked around by it
      // like they should, and if we try to restore their health before they
      // take damage, big hits like standing in a room of exploding barrels can
      // still drop them down below the intended restore target.
      TNT1 A 0 RestorePlayerHealth();
    Idle:
      TNT1 A -1;
      STOP;
  }

  static int GetInt(string name) {
    return ::IndestructableEventHandler.GetInt(name);
  }

  static bool GetBool(string name){
    return ::IndestructableEventHandler.GetBool(name);
  }

  override void AbsorbDamage(
      int damage, Name damageType, out int newdamage,
      Actor inflictor, Actor source, int flags) {
    if (!lives) return;
    console.printf("Taking damage: %d (health=%d)", damage, owner.health);
    if (damage >= owner.health) {
      newdamage = owner.health - 1;
      ActivateIndestructability();
    }
  }

  void GivePowerup(Name power) {
    let force = Powerup(owner.FindInventory(power));
    let duration = GetInt("indestructable_duration")*35; // tics per second
    if (force) {
      force.effectTics = max(force.effectTics, duration);
    } else {
      force = Powerup(owner.GiveInventoryType(power));
      if (!force) return; // PANIC
      force.effectTics = duration;
    }
  }

  void ActivateIndestructability() {
    --lives;
    console.printf("INDESTRUCTABLE!");
    self.SetStateLabel("RestoreHealth");

    GivePowerup("::IndestructableScreenEffect");
    if (GetBool("indestructable_invincibility"))
      GivePowerup("PowerInvulnerable");
    if (GetBool("indestructable_timestop"))
      GivePowerup("PowerTimeFreezer");
    if (GetBool("indestructable_damage_bonus"))
      GivePowerup("::IndestructableDamage");

    console.printf("You have \c[RED]%d\c- extra %s left!",
      lives, lives == 1 ? "life" : "lives");
  }

  void RestorePlayerHealth() {
    owner.GiveInventory("Health", GetInt("indestructable_restore_hp") - owner.health);
  }
}

class ::IndestructableScreenEffect : Powerup {
  Default {
    Powerup.ColorMap 1.0,1.0,1.0, 1.0,0.0,0.0;
    +INVENTORY.NOSCREENBLINK;
  }
}

class ::IndestructableDamage : Powerup {
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage,
      bool passive, Actor inflictor, Actor source, int flags) {
    if (passive) return;
    newdamage = damage*2;
  }
}

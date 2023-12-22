#namespace TFIS;
#debug off;

// This is the 'force', the invisible inventory item that handles actor-local
// event handlers for Indestructable.
class ::IndestructableForce : Inventory {
  ::PlayerInfo info;

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
      // Fallthrough
    DisplayLivesCount:
      // Used to display the "you have X extra lives" message at the start of a
      // level, after gaining/losing lives, etc.
      // A brief delay is added so that it shows up after start-of-level
      // debug logging, the autosave message, etc.
      TNT1 A 15;
      TNT1 A 0 { info.DisplayLivesCount(); }
      GOTO Idle;
    Idle:
      TNT1 A -1;
      STOP;
  }

  void Initialize(::PlayerInfo info) {
    self.info = info;
    self.info.force = self;
    info.ReportLivesCount();
    MoveToTail();
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
  // TODO: certain classes of attack completely bypass all protections, including
  // AbsorbDamage. These will kill the player outright even if Indestructable is
  // in use! Fortunately they are rare, but we should keep an eye out for
  // workarounds.
  void MoveToTail() {
    // Fastpath: if we're already in tail position, nothing to do.
    if (self.inv == null) return;

    Actor head, tail;
    Actor item = owner;
    // Scan the entire inventory to find the item immediately before this one
    // (head) and the current tail item (tail).
    while (item) {
      DEBUG("MoveToTail: inspecting %s", TAG(item));
      if (item.inv == self) head = item;
      if (item.inv == null) tail = item;
      item = item.inv;
    }
    DEBUG("MoveToTail: head=%s, tail=%s", TAG(head), TAG(tail));
    head.inv = self.inv;
    tail.inv = self;
    self.inv = null;
    DEBUG("MoveToTail: head %s; head> %s; tail %s; tail> %s; force> %s",
      TAG(head), TAG(head.inv), TAG(tail), TAG(tail.inv), TAG(force.inv));
  }

  void Message(string msg) {
    owner.A_Log(msg, true);
  }

  bool IsUndying(PlayerInfo player) {
    return player.cheats & (CF_BUDDHA | CF_BUDDHA2 | CF_GODMODE | CF_GODMODE2);
  }

  override void AbsorbDamage(
      int damage, Name damageType, out int newdamage,
      Actor inflictor, Actor source, int flags) {
    if (!info.lives || IsUndying(owner.player)) return;
    if (damage >= owner.health) {
      newdamage = owner.health - 1;
      ActivateIndestructability();
    } else if (!indestructable_gun_bonsai_mode) {
      // The hit that activates invulnerability doesn't contribute to the charge.
      info.AddDamageCharge(damage);
    }
  }

  void GivePowerup(Name power) {
    let force = Powerup(owner.FindInventory(power));
    let duration = indestructable_duration*35; // tics per second
    if (force) {
      force.effectTics = max(force.effectTics, duration);
    } else {
      force = Powerup(owner.GiveInventoryType(power));
      if (!force) return; // PANIC
      force.effectTics = duration;
    }
  }

  void ActivateIndestructability() {
    Message("$TFIS_MSG_ACTIVATED");

    let cv = CVar.FindCVar("indestructable_screen_effect");
    GiveScreenEffect(cv ? cv.GetInt() : -1);
    if (indestructable_invincibility)
      GivePowerup("::IndestructableInvincibility");
    if (indestructable_slomo)
      GivePowerup("::IndestructableSloMo");
    if (indestructable_damage_bonus)
      GivePowerup("::IndestructableDamage");

    if (info.lives > 0) {
      info.AdjustLives(-1, false);
    }
    // Do this after AdjustLives or it will set us to DisplayLivesCount and
    // override the health restoration.
    self.SetStateLabel("RestoreHealth");
  }

  void GiveScreenEffect(uint effect) {
    static const string effects[] = {
      "", "Red", "Gold", "Green", "Blue", "Inverse", "RedWhite", "Desaturate" };
    if (effect <= 0 || effect > 7) return;
    GivePowerup("::IndestructableScreenEffect_"..effects[effect]);

  }

  void RestorePlayerHealth() {
    owner.GiveInventory("Health", indestructable_restore_hp - owner.health);
  }
}

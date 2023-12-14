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
      GOTO Idle;
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
    self.SetStateLabel("RestoreHealth");

    let cv = CVar.FindCVar("indestructable_screen_effect");
    GiveScreenEffect(cv ? cv.GetInt() : -1);
    if (indestructable_invincibility)
      GivePowerup("::IndestructableInvincibility");
    if (indestructable_slomo)
      GivePowerup("::IndestructableSloMo");
    if (indestructable_damage_bonus)
      GivePowerup("::IndestructableDamage");

    if (info.lives > 0) {
      info.AdjustLives(-1, -1, -1);
    }
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

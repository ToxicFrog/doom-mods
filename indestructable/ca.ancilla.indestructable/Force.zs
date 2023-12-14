#namespace TFIS;
#debug off;

class ::IndestructableForce : Inventory {
  int lives;
  int delta_since_report;
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
      TNT1 A 0 DisplayLivesCount();
      GOTO Idle;
    Idle:
      TNT1 A -1;
      STOP;
  }

  void Message(string msg) {
    owner.A_Log(msg, true);
  }

  void DisplayLivesCount() {
    if (lives < 0) {
      Message("$TFIS_MSG_UNLIMITED_LIVES");
    } else if (delta_since_report < 0) {
      Message(string.format(StringTable.Localize("$TFIS_MSG_REDUCED_LIVES"), lives));
    } else if (delta_since_report > 0) {
      Message(string.format(StringTable.Localize("$TFIS_MSG_INCREASED_LIVES"), lives));
    } else {
      Message(string.format(StringTable.Localize("$TFIS_MSG_UNCHANGED_LIVES"), lives));
    }
    delta_since_report = 0;
  }

  bool IsUndying(PlayerInfo player) {
    return player.cheats & (CF_BUDDHA | CF_BUDDHA2 | CF_GODMODE | CF_GODMODE2);
  }

  override void AbsorbDamage(
      int damage, Name damageType, out int newdamage,
      Actor inflictor, Actor source, int flags) {
    if (!lives || IsUndying(owner.player)) return;
    if (damage >= owner.health) {
      newdamage = owner.health - 1;
      ActivateIndestructability();
    }
  }

  void GivePowerup(Name power) {
    let force = Powerup(owner.FindInventory(power));
    let duration = ::Util.GetInt("indestructable_duration")*35; // tics per second
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

    GiveScreenEffect(::Util.GetInt("indestructable_screen_effect"));
    if (indestructable_invincibility)
      GivePowerup("::IndestructableInvincibility");
    if (indestructable_slomo)
      GivePowerup("::IndestructableSloMo");
    if (indestructable_damage_bonus)
      GivePowerup("::IndestructableDamage");

    if (lives > 0) {
      AdjustLives(-1, -1, -1);
    }
  }

  void GiveScreenEffect(uint effect) {
    static const string effects[] = {
      "", "Red", "Gold", "Green", "Blue", "Inverse", "RedWhite", "Desaturate" };
    if (effect <= 0 || effect > 7) return;
    GivePowerup("::IndestructableScreenEffect_"..effects[effect]);

  }

  void RestorePlayerHealth() {
    owner.GiveInventory("Health", ::Util.GetInt("indestructable_restore_hp") - owner.health);
  }

  void AddLevelStartLives() {
    let max_lives = ::Util.GetInt("indestructable_max_lives_per_level");
    AdjustLives(
      ::Util.GetInt("indestructable_lives_per_level"),
      ::Util.GetInt("indestructable_min_lives_per_level"),
      // If life capping is disabled, pass -1 for "no maximum"
      max_lives ? max_lives : -1);
  }

  void AddBossKillLives() {
    let max_lives = ::Util.GetInt("indestructable_max_lives_per_boss");
    AdjustLives(
      ::Util.GetInt("indestructable_lives_per_boss"),
      ::Util.GetInt("indestructable_min_lives_per_boss"),
      // If life capping is disabled, pass -1 for "no maximum"
      max_lives ? max_lives : -1);
  }

  void AdjustLives(int delta, int min_lives, int max_lives) {
    let old_lives = lives;
    if (lives >= 0) {
      lives += delta;
    }
    if (min_lives != -1) lives = max(lives, min_lives);
    if (max_lives != -1) lives = min(lives, max_lives);

    if (old_lives < 0 && lives >= 0) {
      delta_since_report = -9999; // going from infinite to finite lives is a reduction
    } else if (old_lives >= 0 && lives < 0) {
      delta_since_report = 9999; // going from finite to infinite is an increase
    } else {
      delta_since_report += (lives - old_lives); // for everything else use the actual delta
    }
    ReportLivesCount(lives - old_lives);
  }

  void ReportLivesCount(int delta) {
    // Display the message unconditionally, so the player gets reminders as they
    // clear levels and kill bosses even if the lives count didn't change.
    SetStateLabel("DisplayLivesCount");
    if (!delta) return;
    EventHandler.SendNetworkEvent("indestructable_report_lives", lives, delta, 0);
  }
}

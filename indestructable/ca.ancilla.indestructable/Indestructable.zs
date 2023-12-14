#namespace TFIS;
#debug off;

class ::IndestructableEventHandler : StaticEventHandler {
  static int GetInt(string name) {
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetInt();
    return -1;
  }

  static bool GetBool(string name) {
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
    force.lives = GetInt("indestructable_starting_lives");
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
    let lives = GetInt("indestructable_lives_per_boss");
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

  static int GetInt(string name) {
    return ::IndestructableEventHandler.GetInt(name);
  }

  static bool GetBool(string name){
    return ::IndestructableEventHandler.GetBool(name);
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
    Message("$TFIS_MSG_ACTIVATED");
    self.SetStateLabel("RestoreHealth");

    GiveScreenEffect(GetInt("indestructable_screen_effect"));
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
    owner.GiveInventory("Health", GetInt("indestructable_restore_hp") - owner.health);
  }

  void AddLevelStartLives() {
    let max_lives = GetInt("indestructable_max_lives_per_level");
    AdjustLives(
      GetInt("indestructable_lives_per_level"),
      GetInt("indestructable_min_lives_per_level"),
      // If life capping is disabled, pass -1 for "no maximum"
      max_lives ? max_lives : -1);
  }

  void AddBossKillLives() {
    let max_lives = GetInt("indestructable_max_lives_per_boss");
    AdjustLives(
      GetInt("indestructable_lives_per_boss"),
      GetInt("indestructable_min_lives_per_boss"),
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

mixin class IndestructableStopWhenFrozen {
  override void Tick() {
    if (owner && owner.player && owner.player.IsTotallyFrozen()) return;
    super.Tick();
  }
}

class ::IndestructableInvincibility : PowerInvulnerable {
  mixin IndestructableStopWhenFrozen;
}

class ::IndestructableScreenEffect : Powerup {
  mixin IndestructableStopWhenFrozen;
  Default {
    +INVENTORY.NOSCREENBLINK;
  }
}

class ::IndestructableScreenEffect::Red : ::IndestructableScreenEffect
{ Default { Powerup.Color "RedMap"; } }
class ::IndestructableScreenEffect::Gold : ::IndestructableScreenEffect
{ Default { Powerup.Color "GoldMap"; } }
class ::IndestructableScreenEffect::Green : ::IndestructableScreenEffect
{ Default { Powerup.Color "GreenMap"; } }
class ::IndestructableScreenEffect::Blue : ::IndestructableScreenEffect
{ Default { Powerup.Color "BlueMap"; } }
class ::IndestructableScreenEffect::Inverse : ::IndestructableScreenEffect
{ Default { Powerup.Color "InverseMap"; } }
class ::IndestructableScreenEffect::RedWhite : ::IndestructableScreenEffect
{ Default { Powerup.ColorMap 1.0,1.0,1.0, 1.0,0.0,0.0; } }
class ::IndestructableScreenEffect::Desaturate : ::IndestructableScreenEffect
{ Default { Powerup.ColorMap 0.0,0.0,0.0, 1.0,1.0,1.0; } }

class ::IndestructableDamage : Powerup {
  mixin IndestructableStopWhenFrozen;
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage,
      bool passive, Actor inflictor, Actor source, int flags) {
    if (passive) return;
    newdamage = damage*2;
  }
}

class ::IndestructableSlomo : PowerTimeFreezer {
  mixin IndestructableStopWhenFrozen;
  bool ShouldFreeze() {
    return indestructable_slomo == 1 || (level.maptime/2) % indestructable_slomo;
  }

  override void DoEffect() {
    // Check based on PowerTimeFreezer::DoEffect
    // We need to check IsTotallyFrozen() here too, because DoEffect() is called
    // whether or not Tick() is, and that means that even if the player is frozen
    // we'll keep toggling freeze on and off in slow-mo mode, which can interfere
    // with other mods like Gearbox.
    if (Level.maptime & 1
        || (Owner && Owner.player
            && (Owner.player.cheats & CF_PREDICTING || Owner.player.IsTotallyFrozen()))) {
      return;
    }
    DEBUG("maptime=%d effectTics=%d shouldFreeze=%d", effectTics, level.maptime, shouldfreeze());
    Level.setFrozen(effectTics > 0 && ShouldFreeze());
 }

  override bool CanPickup(Actor other) { return true; }
  override bool IsBlinking() { return false; }
}

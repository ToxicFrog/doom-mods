#namespace TFIS;
#debug off;

mixin class ::IndestructableStopWhenFrozen {
  override void Tick() {
    if (owner && owner.player && owner.player.IsTotallyFrozen()) return;
    super.Tick();
  }
}

class ::IndestructableInvincibility : PowerInvulnerable {
  mixin ::IndestructableStopWhenFrozen;
}

class ::IndestructableScreenEffect : Powerup {
  mixin ::IndestructableStopWhenFrozen;
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
  mixin ::IndestructableStopWhenFrozen;
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage,
      bool passive, Actor inflictor, Actor source, int flags) {
    if (passive) return;
    newdamage = damage*2;
  }
}

// Some notes on Tick handling.
// Ticks happen in the order of entries in the thinker table, so it's undefined
// whether a powerup tick happens before or after the tick of the enclosing actor.
// DoEffect(), meanwhile, happens on the enclosing actor's Tick, iff the actor
// is not a player or is a non-predicting player.
// EffectTics, meanwhile, counts down in Tick(), not in DoEffect().
// So, any corrections we need to make have to happen in DoEffect().
class ::IndestructableSlomo : PowerTimeFreezer {
  // Don't tick down the timer while TotallyFrozen().
  mixin ::IndestructableStopWhenFrozen;

  // If the player has multiple timestop effects, and another one expires, it
  // will clear the player's timefreezer fields, causing the player as well to
  // freeze.
  // This function attempts to reinstate the timefreezer flag so that the player
  // is not frozen by their own timestop.
  // Code adapted from PowerTimeFreezer::InitEffect().
  void FixPlayerFlags() {
    if (!owner || !owner.player || !owner.player.timefreezer) return;
    uint freezemask = 1 << owner.PlayerNumber();
    owner.player.timefreezer |= freezemask;
    for (int i = 0; i < MAXPLAYERS; i++) {
      if (playeringame[i] && players[i].mo && players[i].mo.IsTeammate(Owner)) {
        players[i].timefreezer |= freezemask;
      }
    }
  }

  bool ShouldFreeze() {
    return indestructable_slomo == 1 || (level.maptime/2) % indestructable_slomo;
  }

  override void DoEffect() {
    FixPlayerFlags();
    // Check based on PowerTimeFreezer::DoEffect. We don't need to check for
    // CF_PREDICTING here because the caller, AActor::Tick(), already does that.
    // We do however need to check IsTotallyFrozen(), as otherwise we'll end up
    // toggling freeze on and off even if the player is frozen by something like
    // Gearbox, with tragic results.
    if (Level.maptime & 1
        || (Owner && Owner.player && Owner.player.IsTotallyFrozen())) {
      return;
    }
    DEBUG("maptime=%d effectTics=%d shouldFreeze=%d", effectTics, level.maptime, shouldfreeze());
    Level.setFrozen(effectTics > 0 && ShouldFreeze());
  }

  override bool CanPickup(Actor other) { return true; }
  override bool IsBlinking() { return false; }
}

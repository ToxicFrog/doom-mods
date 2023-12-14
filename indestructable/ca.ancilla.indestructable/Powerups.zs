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

class ::IndestructableSlomo : PowerTimeFreezer {
  mixin ::IndestructableStopWhenFrozen;
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

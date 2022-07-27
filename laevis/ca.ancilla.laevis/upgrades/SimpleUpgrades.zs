// Simple upgrades that don't need any aux classes and have simple implementations
#namespace TFLV::Upgrade;

class ::BlastShaping : ::BaseUpgrade {
  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    if (pawn != attacker) return damage;
    return damage * 0.5 ** level;
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

// TODO: put some restrictions on this so you can't stack bouncy, piercing, and
// homing all on the same projectile. Maybe bouncy and piercing are mutually
// exclusive?
class ::BouncyShots : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.bBOUNCEONWALLS = true;
    shot.bBOUNCEONCEILINGS = true;
    shot.bBOUNCEONFLOORS = true;
    shot.bBOUNCEAUTOOFFFLOORONLY = true;
    shot.BounceCount = 1 + level;
    if (level >= 3) {
      shot.bALLOWBOUNCEONACTORS = true;
      shot.bBOUNCEONACTORS = true;
      shot.bBOUNCEONUNRIPPABLES = true;
    }
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsProjectileWeapon();
  }
}

class ::FastShots : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.A_ScaleVelocity(1 + 0.5*level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsProjectileWeapon();
  }
}

class ::PiercingShots : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.bRIPPER = true;
    shot.RipperLevel = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsProjectileWeapon() && info.upgrades.Level("::PiercingShots") < 5;
  }
}

class ::PlayerDamage : ::BaseUpgrade {
  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    // 10% damage bonus per level, but always at least 1 extra point per level.
    double bonus = damage * (self.level * 0.10);
    return damage + (bonus < self.level ? self.level : bonus);
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

class ::Thorns : ::BaseUpgrade {
  override void OnDamageReceived(Actor pawn, Actor shot, Actor attacker, int damage) {
    if (!attacker || pawn == attacker || !attacker.bISMONSTER) return;
    attacker.DamageMobj(pawn, pawn, damage * level, "Thorns", DMG_THRUSTLESS);
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

class ::ToughAsNails : ::BaseUpgrade {
  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    // 10% resistance per level, multiplicative
    double newdamage = damage * (0.90 ** self.level);
    return max(1, min(newdamage, damage - level));
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

class ::WeaponDamage : ::BaseUpgrade {
  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    // 10% damage bonus per level, but always at least 1 extra point per level.
    double bonus = damage * (self.level * 0.10);
    return damage + (bonus < self.level ? self.level : bonus);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }
}

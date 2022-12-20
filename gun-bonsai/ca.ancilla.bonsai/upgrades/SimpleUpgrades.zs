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

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damage-reduction", AsPercentDecrease(0.5**level));
  }
}

class ::BouncyShots : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.bBOUNCEONWALLS = true;
    shot.bBOUNCEONCEILINGS = true;
    shot.bBOUNCEONFLOORS = true;
    shot.bBOUNCEAUTOOFFFLOORONLY = true;
    shot.BounceCount = max(shot.BounceCount, 1 + level);
    shot.BounceFactor = 1.0;
    if (level >= 3) {
      shot.bALLOWBOUNCEONACTORS = true;
      shot.bBOUNCEONACTORS = true;
      shot.bBOUNCEONUNRIPPABLES = true;
    }
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsSlowProjectile()
      && !info.IsRipper()
      && !info.IsBouncer(false);
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("count", ""..(!level ? 0 : 1 + level));
    if (level < 3) {
      fields.insert("extra-effect", "");
    } else {
      fields.insert("extra-effect", GetTooltipFormat(1)); // "Shots bounce off enemies."
    }
  }
}

class ::FastShots : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.A_ScaleVelocity(1 + 0.5*level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsSlowProjectile();
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("v-multiplier", string.format("x%.1f", 1 + 0.5*level));
  }
}

class ::PiercingShots : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.bRIPPER = true;
  }

  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    if (shot.bRIPPER && shot.bMISSILE) {
      // For the plasma rifle, against a Revenant-sized enemy, setting this to 0.5
      // without any other upgrades results in it doing roughly normal damage.
      // With two levels of High Velocity setting it to 0.7 results in about 25%
      // normal damage, which is probably ok?
      return damage * (1.0 - 0.7 ** level);
    }
    return damage;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsProjectile()
      // Not allowed with bouncer or fragmentation shots, and don't spawn on
      // weapons that are natural rippers or already have this upgrade.
      && !info.IsRipper()
      && !info.IsBouncer()
      && info.upgrades.Level("::FragmentationShots") == 0
      // Also requires either FastProjectile weapon or two levels in Fast Shots
      && (info.IsFastProjectile() || info.upgrades.Level("::FastShots") >= 2);
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damage-reduction", AsPercentDecrease(1.0 - 0.7 ** level));
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

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("percent-bonus", AsPercentIncrease(level*0.1));
    fields.insert("flat-bonus", "+"..level);
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

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("percent-bonus", AsPercentDecrease(0.9**level));
    fields.insert("flat-bonus", "-"..level);
  }
}

class ::WeaponDamage : ::BaseUpgrade {
  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    // 20% damage bonus per level, but always at least 1 extra point per level.
    double bonus = damage * (self.level * 0.20);
    return damage + (bonus < self.level ? self.level : bonus);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("percent-bonus", AsPercentIncrease(level*0.2));
    fields.insert("flat-bonus", "+"..level);
  }
}

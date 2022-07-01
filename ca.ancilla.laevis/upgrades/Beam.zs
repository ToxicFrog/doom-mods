#namespace TFLV::Upgrade;

class ::Beam : ::BaseUpgrade {
  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    multiplier = 1.0 - (0.5 ** level);
    pawn.A_CustomRailgun(
      ceil(damage * multiplier),
      0, 0, 0, // horizontal offset and colours
      RGF_SILENT|RGF_FULLBRIGHT,
      0, 0, // spread
      "::Beam::Puff");
    return 0;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsHitscanWeapon() && !info.weapon.bMELEEWEAPON;
  }
}

class ::Beam::Puff : BulletPuff {
  Default {
    +INCOMBAT; // Laevis recursion guard
  }
}

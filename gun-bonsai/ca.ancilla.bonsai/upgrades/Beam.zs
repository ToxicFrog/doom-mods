#namespace TFLV::Upgrade;
#debug on

class ::Beam : ::BaseUpgrade {
  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    if (shot && shot is "::Beam::Puff") return damage;

    double multiplier = 1.0 - (0.5 ** level);
    pawn.A_CustomRailgun(
      ceil(damage * multiplier),
      0, 0, 0, // horizontal offset and colours
      RGF_SILENT|RGF_FULLBRIGHT,
      0, 0, // spread
      "::Beam::Puff");
    return 0;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsHitscan() && !info.weapon.bMELEEWEAPON;
  }
}

// No recursion guard so that other weapon upgrades like dots, explosions, etc
// trigger properly.
class ::Beam::Puff : BulletPuff {
  double x,y,z;
  Default { +ALWAYSPUFF; +PUFFONACTORS; }
  override void PostBeginPlay() {
    DEBUG("BeamPuff spawned: [%d, %d, %d]", pos.x, pos.y, pos.z);
    x = pos.x; y = pos.y; z = pos.z;
  }
}

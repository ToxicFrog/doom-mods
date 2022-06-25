// Melee-only upgrades.
// These tend to be much more powerful than the non-melee equivalents.

// Like Resistance, but a much more powerful melee-only version.
// 50% resistance, 75% when upgraded.
class ::Shield : ::BaseUpgrade {
  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    return damage * (0.5 ** self.level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.weapon.bMELEEWEAPON && info.upgrades.Level("::Shield") < 2;
  }
}

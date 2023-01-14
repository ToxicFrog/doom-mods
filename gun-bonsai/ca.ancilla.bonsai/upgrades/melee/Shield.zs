#namespace TFLV::Upgrade;
#debug off;

// Like Resistance, but a much more powerful melee-only version.
// Starts at ~18% resistance and improves with diminishing returns to a max
// of 60%.
class ::Shield : ::BaseUpgrade {
  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    return max(1, damage * (0.4 + 0.6 * 0.8 ** self.level));
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return (info.IsMelee() || info.IsWimpy());
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("shield", AsPercentDecrease(0.4 + 0.6 * 0.8 ** level));
  }
}

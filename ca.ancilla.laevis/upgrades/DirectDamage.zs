#namespace TFLV::Upgrade;

class ::DirectDamage : ::BaseUpgrade {
  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    return damage * (1.0 + self.level * TFLV_Settings.player_damage_bonus());
  }
}

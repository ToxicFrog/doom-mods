class TFLV_Upgrade_DirectDamage : TFLV_BaseUpgrade {
  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    console.printf("DirectDamage upgrade: before %d -> after %d",
      damage, damage * (1.0 + self.level * TFLV_Settings.player_damage_bonus()));
    return damage * (1.0 + self.level * TFLV_Settings.player_damage_bonus());
  }
}

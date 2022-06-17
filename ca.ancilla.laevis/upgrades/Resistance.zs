class TFLV_Upgrade_Resistance : TFLV_BaseUpgrade {
  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    return damage * (TFLV_Settings.player_defence_bonus() ** self.level);
  }
}

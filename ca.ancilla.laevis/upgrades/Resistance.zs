class TFLV_Upgrade_Resistance : TFLV_BaseUpgrade {
  override double ModifyDamageReceived(PlayerPawn player, Actor shot, Actor attacker, double damage) {
    return damage * (TFLV_Settings.player_defence_bonus() ** self.level);
  }
}

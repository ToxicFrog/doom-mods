#namespace TFLV::Upgrade;

class ::Resistance : ::BaseUpgrade {
  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    return damage * (TFLV::Settings.player_defence_bonus() ** self.level);
  }
}

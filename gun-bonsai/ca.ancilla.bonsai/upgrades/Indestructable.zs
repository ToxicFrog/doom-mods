#namespace TFLV::Upgrade;

class ::Indestructable : ::BaseUpgrade {
  int charge;
  override void OnDamageReceived(Actor pawn, Actor shot, Actor attacker, int damage) {
    if (pawn == attacker) return;
    charge += damage;
    // Charge between lives starts at 200 and asymptotically approaches 100.
    let maxCharge = 100 + (200 * 0.5**level);
    if (charge >= maxCharge) {
      charge -= maxCharge;
      pawn.A_SetBlend("FF FF 00", 0.8, 40);
      EventHandler.SendNetworkEvent("indestructable_adjust_lives", 1, 0, 2**level);
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return stats.upgrades.Level("::Indestructable") < 3;
  }
}


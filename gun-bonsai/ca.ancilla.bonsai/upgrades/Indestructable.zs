#namespace TFLV::Upgrade;

class ::Indestructable : ::BaseUpgrade {
  int charge;
  override void OnDamageReceived(Actor pawn, Actor shot, Actor attacker, int damage) {
    if (pawn == attacker) return;
    charge += damage;
    let maxCharge = GetMaxCharge(level);
    if (charge >= maxCharge) {
      charge -= maxCharge;
      pawn.A_SetBlend("FF FF 00", 0.8, 40);
      EventHandler.SendNetworkEvent("indestructable_adjust_lives", 1, 0, 2**level);
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return stats.upgrades.Level("::Indestructable") < 3
      && CVar.FindCVar("indestructable_starting_lives").GetInt() == 0
      && CVar.FindCVar("indestructable_lives_per_level").GetInt() == 0;
  }

  // Charge between lives starts at 200 and asymptotically approaches 100.
  static int GetMaxCharge(uint level) {
    if (!level) return 0;
    return 100 + (200 * 0.5**level);
  }

  override void GetTooltipFields(Array <string> fields, uint level) {
    fields.push(""..GetMaxCharge(level));
    fields.push(string.format("%d", 2**level));
  }
}


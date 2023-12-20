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
      EventHandler.SendNetworkEvent("indestructable-adjust-lives", 1, 0);
      EventHandler.SendNetworkEvent("indestructable-clamp-lives", 0, 2**level);
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return stats.upgrades.Level("::Indestructable") < 3
      && CVar.FindCVar("indestructable_gun_bonsai_mode").GetBool() == true;
  }

  // Charge between lives starts at 200 and asymptotically approaches 100.
  static int GetMaxCharge(uint level) {
    if (!level) return 0;
    return 100 + (200 * 0.5**level);
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damage-per-life", ""..GetMaxCharge(level));
    fields.insert("max-lives", string.format("%d", 2**level));
  }
}

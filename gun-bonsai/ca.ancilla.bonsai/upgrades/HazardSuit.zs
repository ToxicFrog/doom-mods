#namespace TFLV::Upgrade;
#debug off;

class ::HazardSuit : ::BaseUpgrade {
  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage, Name attacktype) {
    // We don't actually have a 100% reliable way of telling if the damage came from a hurtfloor.
    // So we use the following heuristic:
    // - shot and attacker both null
    // - player standing on a hurtfloor
    // - received damage type == floor damage type
    // - damage is <= configured hurtfloor damage (it may be < because the player
    //   has other protections, e.g. Tough as Nails)
    if (shot || attacker) return damage;
    if (!pawn.curSector.damageamount || pawn.curSector.damagetype != attacktype) return damage;
    if (damage > pawn.curSector.damageAmount) return damage;
    DEBUG("DamageReceived: sector=%d csD=%s(%d) dam=%f",
      pawn.CurSector.sectornum, pawn.CurSector.damagetype, pawn.CurSector.damageamount, damage);
    return ceil(damage * GetDamageModifier(self.level));
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }

  float GetDamageModifier(uint level) {
    return 0.5 ** level;
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damage-reduction", AsPercentDecrease(GetDamageModifier(level)));
  }
}

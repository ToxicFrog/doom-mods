#namespace TFLV::Upgrade;
#debug off

class ::AggressiveDefence : ::BaseUpgrade {
  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsHitscan();
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("radius", AsMeters(GetRadius(level)));
    fields.insert("pct-bonus", AsPercentIncrease(GetBonus(level)));
  }

  uint GetRadius(uint level) {
    return 64 + 32*level;
  }

  float GetBonus(uint level) {
    return 1.0 + 0.01 * level;
  }

  static bool IsEnemyMissile(Actor act) {
    return act.bMISSILE // Must be missile-flagged
      && (!act.target || !act.target.player) // Not owned by a player
      && act.speed < 300; // Super-fast missiles are ersatz hitscans
  }

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    if (!shot || !target) return;
    let radius = GetRadius(self.level) * GetBonus(self.level);
    ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
    Actor act;
    while (act = Actor(it.next())) {
      if (!IsEnemyMissile(act) || act.Distance3D(target) > radius)
        continue;
      act.Die(pawn, shot);
    }
  }
}

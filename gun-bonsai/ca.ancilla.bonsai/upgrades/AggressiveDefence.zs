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

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    if (!shot || !target) return;
    let radius = GetRadius(self.level) * GetBonus(self.level);
    ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
    Actor act;
    while (act = Actor(it.next())) {
      if (!act.bMISSILE || (act.target && act.target.player) || act.Distance3D(target) > radius)
        // Skip things that aren't missiles, and missiles which are controlled by a player.
        continue;
      act.SetStateLabel("Death");
    }
  }
}

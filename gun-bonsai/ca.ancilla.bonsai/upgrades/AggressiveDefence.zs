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
    return 0.01 * level;
  }

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    if (!shot || !target) return;
    let radius = GetRadius(self.level) * (1.0 + GetBonus(self.level));
    ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
    Actor projectile;
    while (projectile = Actor(it.next())) {
      if ((projectile.target && projectile.target.player) || target.Distance3D(projectile) > radius) {
        // Skip shots that are owned by a player and shots that are too far away
        // from the target.
        continue;
      }
      projectile.SetStateLabel("Death");
    }
  }

}


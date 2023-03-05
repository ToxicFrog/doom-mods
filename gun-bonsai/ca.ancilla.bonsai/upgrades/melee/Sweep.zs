#namespace TFLV::Upgrade;
#debug off;

class ::Sweep : ::BaseUpgrade {
  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    let radius = 128; // 4m, twice chainsaw range and 2/3rds of nominal melee range
    if (shot is "::Sweep::Aux") return;
    if (pawn.Distance3D(target) > radius) return;
    // Find all potential targets in melee range of player
    Array<Actor> targets;
    ::Sweep::Aux aux;
    TFLV::Util.MonstersInRadius(pawn, radius, targets);
    for (uint i = 0; i < targets.size(); ++i) {
      DEBUG("Range to target %s is %f", TAG(targets[i]), target.Distance3D(targets[i]));
      // Target also needs to be in melee range of the thing we're attacking
      if (target.Distance3D(targets[i]) > radius) continue;
      // Don't double-dip
      if (target == targets[i]) continue;
      DEBUG("Damaging sweep target %s for %d", TAG(targets[i]), damage);
      if (!aux) aux = ::Sweep::Aux(pawn.Spawn("::Sweep::Aux"));
      aux.hit(pawn, targets[i], ceil(damage * DamageMultiplier(level)));
    }
    if (aux) aux.Destroy();
  }

  double DamageMultiplier(uint level) {
    return 0.8 - (0.6 ** level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsMelee();
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damagepct", AsPercent(DamageMultiplier(level)));
  }
}

class ::Sweep::Aux : Actor {
  void hit(Actor source, Actor target, uint damage) {
    target.DamageMobj(self, source, damage, "Melee", DMG_INFLICTOR_IS_PUFF|DMG_PLAYERATTACK);
  }
}
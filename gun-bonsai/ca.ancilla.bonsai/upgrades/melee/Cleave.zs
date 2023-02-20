#namespace TFLV::Upgrade;
#debug off;

class ::Cleave : ::BaseUpgrade {
  override void OnKill(PlayerPawn pawn, Actor shot, Actor target) {
    let radius = 128; // 4m, twice chainsaw range and 2/3rds of nominal melee range
    if (pawn.Distance3D(target) > radius) return;
    // Find all potential targets in melee range of player
    Array<Actor> targets;
    TFLV::Util.MonstersInRadius(pawn, radius, targets);
    for (uint i = 0; i < targets.size(); ++i) {
      if (targets[i] == target) continue;
      DEBUG("Range to target %s is %f and it has %d health",
        TAG(targets[i]), target.Distance3D(targets[i]), targets[i].health);
      ::Cleave::Aux aux = ::Cleave::Aux(pawn.Spawn("::Cleave::Aux"));
      aux.hit(pawn, targets[i], ceil(
          targets[i].SpawnHealth() * HealthMultiplier(level)
          + abs(target.health) * OverkillMultiplier(level)));
      break;
    }
  }

  // TODO: figure out cleave damage.
  // At the moment it's just based on the target's max health + the damage dealt
  // by the attack that killed it.
  // Scales from 100% -> infinity by 25% at a time.
  double OverkillMultiplier(uint level) {
    return 1.0 + level * 0.25;
  }
  // Scales from 10% -> 50%
  double HealthMultiplier(uint level) {
    return (1.0 - 0.8 ** level) * 0.5;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsMelee();
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("healthpct", AsPercent(HealthMultiplier(level)));
    fields.insert("overkillpct", AsPercent(OverkillMultiplier(level)));
  }
}

class ::Cleave::Aux : Actor {
  void hit(Actor source, Actor target, uint damage) {
    DEBUG("Cleaving %s for %d damage", TAG(target), damage);
    target.DamageMobj(self, source, damage, "Melee", DMG_INFLICTOR_IS_PUFF|DMG_PLAYERATTACK);
  }
}
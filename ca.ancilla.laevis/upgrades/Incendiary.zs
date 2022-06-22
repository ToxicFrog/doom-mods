#namespace TFLV::Upgrade;

class ::IncendiaryShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    ::Dot.GiveStacks(player, target, "::IncendiaryShots::Fire", level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }
}

// Fire will try to do this proportion of the target's health in damage.
const FIRE_FACTOR = 0.5;

class ::IncendiaryShots::Fire : ::Dot {
  uint totalDamage;
  uint maxDamage;

  Default {
    DamageType "Fire";
  }

  override void PostBeginPlay() {
    super.PostBeginPlay();
    if (!owner) return;
    totalDamage = 0;
    maxDamage = owner.SpawnHealth() * FIRE_FACTOR;
  }

  override string GetParticleColour() {
    static const string colours[] = { "red", "orange", "yellow" };
    return colours[random(0,2)];
  }

  override double GetParticleZV() {
    return 0.1;
  }

  // TODO: use A_RadiusGive to spread fire to nearby monsters.
  // This probably requires the use of HandlePickup() to check the amount
  // in order to differentiate between new stacks applied by getting shot
  // and new stacks applied by fire spread
  override uint GetDamage() {
    // Damage calculation. This is a bit hairy.
    // Basically, we want to do at least as much total damage as half the target's
    // health, even if that kills them, but also keep doing damage as long as they
    // have more than half their max, to effectively counter enemies that heal.
    // A few examples:
    // 100/100 health: do 50 damage.
    // 40/100 health: do 50 damage, killing the target.
    // 100/100 health but heals to 200 just before dying: 50 damage, then once the
    // player nearly kills it, re-ignite and burn it more until it's down to 50hp.

    // Step one is to figure out the target amount of damage, which is whichever
    // is greater of "the amount of damage we have to do to have done half their
    // max health in damage total" and "the amount of damage we have to do to bring
    // them down to half health right now". For most enemies #1 will be more, for
    // healing/regenerating enemies it might be #2.

    // You'd think we could use max() here, but for some reason it falls over
    // and dies, returning (int)0x80000000 no matter the input.
    // int target_damage = max(
    //     maxDamage - totalDamage,
    //     owner.health - owner.SpawnHealth() * FIRE_FACTOR);

    int damage_by_spawn = maxDamage - totalDamage;
    int damage_by_health = owner.health - owner.SpawnHealth() * FIRE_FACTOR;
    int target_damage = damage_by_spawn > damage_by_health ?
        damage_by_spawn : damage_by_health;
    DEBUG("Fire damage target=%d out of %d (base) %d (healed)",
      target_damage, damage_by_spawn, damage_by_health);
    if (target_damage <= 0) return 0; // burned out

    // Now the actual damage is a proportion of the target damage, but capped
    // based on the number of stacks we have. It cannot go below 1.
    uint damage = clamp(target_damage/10, 1, amount*4);
    DEBUG("Fire: %d damage", damage);
    totalDamage += damage;
    return damage;
  }
}

class ::Pyre : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    // target.Spawn("::Pyre::Aux", target.pos);
    bool ok; Actor act;
    [ok, act] = shot.A_SpawnItemEx(
      "::Pyre::Aux",
      0, 0, 0, 0, 0, 0, 0,
      SXF_TRANSFERPOINTERS);
    let pyre = ::Pyre::Aux(act);
    pyre.level = level; // TODO: scale with amount of burning on the target
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::IncendiaryShots") > 0;
  }
}

class ::Pyre::Aux : Actor {
  uint level;

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    DEBUG("DoSpecialDamage: %s", target.GetClassName());
    ::Dot.GiveStacks(self.target, target, "::IncendiaryShots::Fire", 1, level);
    return 0;
  }
  States {
    Spawn:
      LFIR ABABCBCDCDEDEFEFGH 7 A_Explode(100, 100, XF_NOSPLASH, false, 100);
      STOP;
  }
}

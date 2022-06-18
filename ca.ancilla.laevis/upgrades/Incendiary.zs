#namespace TFLV::Upgrade;
#debug on

class ::IncendiaryShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    let fire = ::IncendiaryFire(target.GiveInventoryType("::IncendiaryFire"));
    if (fire && fire.owner) {
      fire.target = player;
    }
  }
}

class ::IncendiaryFire : ::Dot {
  uint totalDamage;
  uint maxDamage;

  Default {
    DamageType "Fire";
  }

  override void PostBeginPlay() {
    super.PostBeginPlay();
    if (!owner) return;
    totalDamage = 0;
    maxDamage = owner.SpawnHealth() * 0.5;
  }

  override string GetParticleColour() {
    string colours[] = { "red", "orange", "yellow" };
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
    uint damage = min(amount, maxDamage - totalDamage);
    totalDamage += damage;
    return damage;
  }
}

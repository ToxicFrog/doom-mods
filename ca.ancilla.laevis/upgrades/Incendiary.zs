#namespace TFLV::Upgrade;

class ::IncendiaryShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    ::Dot.GiveStacks(player, target, "::IncendiaryShots::Fire", level);
  }
}

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
    maxDamage = owner.SpawnHealth() * 0.5;
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
    // TODO: bring target down to half health even if they heal
    uint damage = min(amount, maxDamage - totalDamage);
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
    pyre.level = level;
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

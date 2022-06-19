
#namespace TFLV::Upgrade;
#debug on

class ::IncendiaryShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    // TODO: scale amount of fire with level.
    // We can't use GiveInventory() for this easily, because it doesn't return a
    // pointer to the added inventory. But GiveInventoryType() doesn't let us specify
    // an amount.
    // We may end up using Spawn() to create the item, set the amount,
    // then item.TryPickup(target).
    let fire = ::IncendiaryShots::Fire(target.GiveInventoryType("::IncendiaryShots::Fire"));
    if (fire && fire.owner) {
      fire.target = player;
    }
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
    target.Spawn("::Pyre::Aux", target.pos);
  }
}

class ::Pyre::Aux : Actor {
  void IgniteNearby() {
    // TODO: give an amount based on how much the victim had when it died
    // TODO: don't give multiple fires to enemies that are already burning
    A_RadiusGive("::IncendiaryShots::Fire", 100, RGF_MONSTERS, 1);
  }
  States {
    Spawn:
      FIRE ABABCBCDCDEDEFEFGH 7 IgniteNearby();
      STOP;
  }
}

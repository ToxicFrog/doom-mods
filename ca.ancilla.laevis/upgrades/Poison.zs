#namespace TFLV::Upgrade;

class ::PoisonShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    ::Dot.GiveStacks(player, target, "::Poison", level*10);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }
}

class ::Poison : ::Dot {
  Default {
    DamageType "Poison";
    Inventory.Amount 10;
  }

  override string GetParticleColour() {
    static const string colours[] = { "green", "green1", "black" };
    return colours[random(0,2)];
  }

  override double GetParticleZV() {
    return -0.1;
  }

  override uint GetDamage() {
    if (amount <= 0) {
      Destroy();
      return 0;
    }
    DEBUG("poison stacks=%d damage=%d", amount, (amount-1)/5);
    return (amount--)/5;
  }
}

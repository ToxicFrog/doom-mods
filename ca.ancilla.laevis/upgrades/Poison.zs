#namespace TFLV::Upgrade;
#debug on

class ::PoisonShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    let poison = ::Poison(target.GiveInventoryType("::Poison"));
    if (poison && poison.owner) {
      poison.target = player;
    }
  }
}

class ::Poison : ::Dot {
  Default {
    DamageType "Poison";
    Inventory.Amount 10;
  }

  override string GetParticleColour() {
    string colours[] = { "green", "green1", "black" };
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
    return (amount--)/5;
  }
}

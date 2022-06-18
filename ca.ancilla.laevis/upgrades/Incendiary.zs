#namespace TFLV::Upgrade;
#debug on

class ::IncendiaryShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    let fire = ::IncendiaryFire(target.GiveInventoryType("::IncendiaryFire"));
    if (fire && fire.owner) {
      fire.target = player;
      fire.SetStateLabel("Burn");
    }
  }
}

class ::IncendiaryFire : Inventory {
  uint totalDamage;
  uint maxDamage;

  Default {
    DamageType "Fire";
    +INCOMBAT; // Laevis recursion guard
    Inventory.Amount 1;
    Inventory.MaxAmount 0x7FFFFFFF;
  }
  States {
    Burn:
      TNT1 A 0 SpawnParticles();
      TNT1 A 7 Burn();
      LOOP;
  }

  override void PostBeginPlay() {
    if (!owner) { Destroy(); return; }
    totalDamage = 0;
    maxDamage = owner.SpawnHealth() * 0.5;
  }

  void SpawnFireParticle(string colour) {
    owner.A_SpawnParticle(
      colour, SPF_FULLBRIGHT,
      30, 10, 0, // lifetime, size, angle
      // position
      random(-owner.radius, owner.radius), random(-owner.radius, owner.radius), random(0, owner.height/2),
      0, 0, 0.1, // v
      0, 0, 0.1); // a
  }
  void SpawnParticles() {
    for (uint i = 0; i < 3; i++) {
      SpawnFireParticle("red");
      SpawnFireParticle("orange");
      SpawnFireParticle("yellow");
    }
  }
  void Burn() {
    // TODO: use A_RadiusGive to spread fire to nearby monsters.
    // This probably requires the use of HandlePickup() to check the amount
    // in order to differentiate between new stacks applied by getting shot
    // and new stacks applied by fire spread
    if (!owner || owner.bKILLED) {
      Destroy();
      return;
    }
    uint damage = min(amount, maxDamage - totalDamage);
    totalDamage += damage;
    owner.DamageMobj(
      self, self.target, damage, self.DamageType,
      DMG_NO_ARMOR | DMG_NO_PAIN | DMG_THRUSTLESS | DMG_NO_ENHANCE);
  }
}

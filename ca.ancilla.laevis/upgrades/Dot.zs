// Generic class for DoT effects.
// Subclasses should implement GetParticleColour(), GetParticleZV(), and GetDamage().
// All of these are called every 7 tics (5 times/second) to draw particle effects
// and apply damage.
// They can also override TickDot(), which is the superfunction that calls
// GetDamage().
#namespace TFLV::Upgrade;

class ::Dot : Inventory {
  Default {
    DamageType "None";
    Inventory.Amount 1;
    Inventory.MaxAmount 0x7FFFFFFF;
    +INCOMBAT; // Laevis recursion guard
  }

  States {
    Dot:
      TNT1 A 0 SpawnParticles();
      TNT1 A 7 TickDot();
      LOOP;
  }

  override void PostBeginPlay() {
    if (!owner) { Destroy(); return; }
    buffer = 0.0;
    SetStateLabel("Dot");
  }

  // Give count stacks of cls to the target, but don't let their total amount
  // exceed max. Assign the dot's parent (via the target pointer) to owner, so
  // that damage it deals is properly attributed.
  static void GiveStacks(Actor owner, Actor target, string cls, uint count, uint max = 0x7FFFFFFF) {
    DEBUG("GiveStacks: %d of %s", count, cls);
    Inventory item = target.FindInventory(cls);
    if (item) {
      item.amount = min(item.amount + count, max);
      DEBUG(" -> amount=%d", item.amount);
    } else {
      item = target.GiveInventoryType(cls);
      if (item) {
        item.target = owner;
        item.amount = min(count, max);
        DEBUG(" -> amount=%d", item.amount);
      }
      DEBUG(" -> failed to GiveInventoryType!");
    }
  }

  // Count how many stacks of the dot the target has. Return 0 if they don't have
  // it at all.
  static uint CountStacks(Actor target, string cls) {
    let dotitem = ::Dot(target.FindInventory(cls));
    if (!dotitem) return 0;
    return dotitem.amount;
  }

  void SpawnParticles() {
    for (uint i = 0; i < 9; i++) {
      SpawnOneParticle(GetParticleColour(), GetParticleZV());
    }
  }

  void SpawnOneParticle(string colour, double zv) {
    owner.A_SpawnParticle(
      colour, SPF_FULLBRIGHT,
      30, 10, 0, // lifetime, size, angle
      // position
      random(-owner.radius, owner.radius), random(-owner.radius, owner.radius), random(0, owner.height),
      0, 0, zv, // v
      0, 0, zv); // a
  }

  double buffer; // Accumlated damage for fractional damage amounts.
  virtual void TickDot() {
    if (!owner || owner.bKILLED) {
      Destroy();
      return;
    }
    buffer += GetDamage();
    if (buffer > 1) {
      owner.DamageMobj(
        self, self.target, floor(buffer), self.DamageType,
        DMG_NO_ARMOR | DMG_NO_PAIN | DMG_THRUSTLESS | DMG_NO_ENHANCE);
      buffer -= floor(buffer);
    }
  }

  virtual double GetDamage() {
    ThrowAbortException("Subclass of ::Dot did not implement GetDamage()!");
    return 0.0;
  }

  virtual string GetParticleColour() {
    ThrowAbortException("Subclass of ::Dot did not implement GetParticleColour()!");
    return "black";
  }

  virtual double GetParticleZV() {
    ThrowAbortException("Subclass of ::Dot did not implement GetParticleZV()!");
    return 0;
  }
}

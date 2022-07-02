// Generic class for DoT effects.
// Subclasses should implement GetParticleColour(), GetParticleZV(), and GetDamage().
// All of these are called every 7 tics (5 times/second) to draw particle effects
// and apply damage.
// They can also override TickDot(), which is the superfunction that calls
// GetDamage().
#namespace TFLV::Upgrade;

class ::Dot : Inventory {
  double stacks;

  Default {
    DamageType "None";
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INCOMBAT; // Laevis recursion guard
  }

  States {
    Dot:
      TNT1 A 0 TickDot();
      TNT1 A 7 SpawnParticles();
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
  static ::Dot GiveStacks(Actor owner, Actor target, string cls, double count, double max = double.infinity) {
    DEBUG("GiveStacks: %f of %s", count, cls);
    ::Dot item = ::Dot(target.FindInventory(cls));
    if (item) {
      item.stacks = min(item.stacks + count, max);
      DEBUG(" -> stacks=%f", item.stacks);
      return item;
    } else {
      item = ::Dot(target.GiveInventoryType(cls));
      if (item) {
        item.target = owner;
        item.stacks = min(count, max);
        DEBUG(" -> stacks=%d", item.stacks);
        return item;
      }
      DEBUG(" -> failed to GiveInventoryType!");
      return null;
    }
  }

  // Count how many stacks of the dot the target has. Return 0 if they don't have
  // it at all.
  static uint CountStacks(Actor target, string cls) {
    let dotitem = ::Dot(target.FindInventory(cls));
    if (!dotitem) return 0;
    return dotitem.stacks;
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
    if (!owner || owner.bKILLED || stacks <= 0) {
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

class ::DotModifier : ::BaseUpgrade {
  virtual string DotType() { return ""; }

  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    let dot_item = ::Dot(target.FindInventory(DotType()));
    if (!dot_item) return;
    ModifyDot(player, shot, target, damage, dot_item);
  }

  virtual void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    return;
  }
}

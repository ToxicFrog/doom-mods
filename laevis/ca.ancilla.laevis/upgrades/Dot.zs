// Generic class for DoT effects.
// Subclasses should implement GetParticleColour(), GetParticleZV(), and GetDamage().
// All of these are called every 7 tics (5 times/second) to draw particle effects
// and apply damage.
// They can also override TickDot(), which is the superfunction that calls
// GetDamage().
#namespace TFLV::Upgrade;

class ::Dot : Inventory {
  double stacks;
  property UpgradePriority: special1;

  Default {
    DamageType "None";
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    ::Dot.UpgradePriority ::PRI_ELEMENTAL;
    +NODAMAGETHRUST;
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

  // Convert between effective stacks (i.e. the amount stored in self.stacks and
  // used for damage calculations and whatnot) and applied stacks (i.e. the amount
  // actually applied by the player before softcapping is calculated).
  // We need both because some things (stacks ticking down with time) modify the
  // effective stacks and other things (attacks with elemental procs) modify the
  // applied stacks.
  // Softcap is defined by the curve y = log10(x^2.1)+1 {x>1}, where x is the
  // applied stacks as a proportion of cap (so as/cap) and y is the same for
  // effective stacks.
  static double EffectiveToApplied(double es, double cap) {
    if (es <= cap) return es;
    return (10.0**(((es/cap) - 1)/2.1)) * cap;
  }

  static double AppliedToEffective(double as, double cap) {
    if (as <= cap) return as;
    return (log10((as/cap)**2.1)+1) * cap;
  }

  // Calculate how many stacks we should end up with taking diminishing returns
  // once the softcap is exceeded into account.
  void AddStacks(double extra, double cap) {
    self.stacks = AppliedToEffective(
      EffectiveToApplied(self.stacks, cap) + extra,
      cap);
  }

  // Give count stacks of cls to the target, but don't let their total amount
  // exceed max. Assign the dot's parent (via the target pointer) to owner, so
  // that damage it deals is properly attributed.
  static ::Dot GiveStacks(Actor owner, Actor target, string cls, double count, double max = double.infinity) {
    DEBUG("GiveStacks: %f of %s", count, cls);
    ::Dot item = ::Dot(target.FindInventory(cls));
    if (!item) item = ::Dot(target.GiveInventoryType(cls));
    if (!item) {
      // Couldn't find it or give them a new one!
      DEBUG(" -> failed to GiveInventoryType!");
      return null;
    }

    item.target = owner;
    item.AddStacks(count, max);
    return item;
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

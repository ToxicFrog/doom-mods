// The poison (earth) upgrade tree.
//
// APPRENTICE: POISON SHOTS
// Damages enemies continually. Duration scales linearly with number of stacks,
// damage scales with square root.
//
// JOURNEYMAN: WEAKNESS
// Poisoned enemies do less damage in proportion to the number of stacks.
//
// MASTER: PUTREFACTION
// Dead enemies will explode in a cloud of poison, spreading it to nearby
// enemies.
//
// MASTER: HALLUCINOGENS
// Poisoned enemies will turn against their friends and fight for the player
// once there is enough poison stacked on them to eventually kill them.
#namespace TFLV::Upgrade;
#debug on

class ::PoisonShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    ::Dot.GiveStacks(player, target, "::PoisonDot", level*10);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }
}

class ::Weakness : ::DotModifier {
  override string DotType() { return "::PoisonDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::PoisonDot(dot_item).weakness = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::PoisonShots") > info.upgrades.Level("::Weakness");
  }
}

class ::Hallucinogens : ::DotModifier {
  override string DotType() { return "::PoisonDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::PoisonDot(dot_item).hallucinogens = level;
    DEBUG("Set hallucinogen level=%d", level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::Weakness") > info.upgrades.Level("::Hallucinogens")
      && info.upgrades.Level("::Putrefaction") == 0;
  }
}

// Poison DoT. Note that it burns one stack per dot tick, so 5 stacks == 1 second.
class ::PoisonDot : ::Dot {
  uint weakness;
  uint hallucinogens;

  Default {
    DamageType "Poison";
    +INCOMBAT; // Laevis recursion guard
    +NODAMAGETHRUST;
  }

  override string GetParticleColour() {
    static const string colours[] = { "green", "green1", "black" };
    return colours[random(0,2)];
  }

  override double GetParticleZV() {
    return -0.1;
  }

  // Approximate total damage potential of all remaining poison stacks.
  double GetTotalDamage() {
    return (2.0/3.0) * (amount/5.0)**(3.0/2.0) * 2.5;
  }

  override double GetDamage() {
    DEBUG("GetDamage: hallu=%d damage=%f health=%d", hallucinogens, GetTotalDamage(), owner.health);
    if (hallucinogens > 0 && GetTotalDamage() >= owner.health && !owner.bFRIENDLY) {
      DEBUG("Made the %s friendly!", owner.GetClassName());
      owner.bFRIENDLY = true;
      owner.bDONTHARMCLASS = false;
      owner.bDONTHARMSPECIES = false;
    }
    // DEBUG("poison stacks=%d damage=%f", amount, ((amount--)/5)**0.5);
    return ((amount--)/5)**0.5 / 2.0; // poison damage scales with square root of remaining seconds
  }

  // Damage modifier for Weakness and Hallucinogens upgrades.
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (passive && damage <= 0 || weakness <= 0 || amount <= 0) {
      return;
    }

    // Outgoing damage. Scale it down based on the number of poison stacks.
    // ...unless the monster is friendly, in which case it gets stronger.
    if (owner.bFRIENDLY) {
      newdamage = ceil(damage * (1.0 + 0.01 * amount * hallucinogens));
    } else {
      newdamage = max(1, floor(damage * 0.99 ** (amount * weakness)));
    }
    DEBUG("Weakness: %d -> %d", damage, newdamage);
  }
}

class ::Putrefaction : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    uint amount = ::Dot.CountStacks(target, "::PoisonDot");
    DEBUG("killed %s, poison stacks=%d", TFLV::Util.SafeCls(target), amount);
    if (amount <= 0) return;

    let aux = ::Putrefaction::Aux(target.Spawn("::Putrefaction::Aux", target.pos));
    aux.target = player;
    aux.level = max(amount - (amount * 0.5**level), 5);
    DEBUG("spawned putrefaction cloud with level=%d", aux.level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::Weakness") > info.upgrades.Level("::Putrefaction")
      && info.upgrades.Level("::Hallucinogens") == 0;
  }
}

class ::Putrefaction::Aux : Actor {
  uint level;

  Default {
    RenderStyle "Translucent";
    Alpha 0.4;
    +NODAMAGETHRUST;
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    ::Dot.GiveStacks(self.target, target, "::PoisonDot", level, level);
    return 0;
  }
  States {
    Spawn:
      LPBX ABABABCBCBCDCDCDEE 7 A_Explode(1, 100, XF_NOSPLASH, false, 100);
      STOP;
  }
}

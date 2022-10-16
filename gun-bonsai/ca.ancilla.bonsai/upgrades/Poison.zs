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
#debug off

class ::PoisonShots : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_POISON; }
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    // Apply one stack (== 1 second or about 2 points of damage) per shot.
    // Softcap at 10*level.
    ::Dot.GiveStacks(player, target, "::PoisonDot", level, 10*level);
    DEBUG("Gave %s %d stacks", target.GetClassName(), level);
  }
}

class ::Weakness : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_POISON; }
  override string DotType() { return "::PoisonDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::PoisonDot(dot_item).weakness = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasIntermediatePrereq(info, "::PoisonShots");
  }
}

class ::Hallucinogens : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_POISON; }
  override string DotType() { return "::PoisonDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::PoisonDot(dot_item).hallucinogens = level;
    DEBUG("Set hallucinogen level=%d", level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::Weakness", "::Putrefaction");
  }
}

class ::Putrefaction : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_POISON; }
  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    double stacks = ::Dot.CountStacks(target, "::PoisonDot");
    DEBUG("killed %s, poison stacks=%d", TFLV::Util.SafeCls(target), stacks);
    if (stacks <= 0) return;

    let aux = ::Putrefaction::Aux(target.Spawn("::Putrefaction::Aux", target.pos));
    aux.target = player;
    aux.level = max(stacks - (stacks * 0.5**level), 1);
    DEBUG("spawned putrefaction cloud with level=%d", aux.level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::Weakness", "::Hallucinogens");
  }
}

class ::PoisonDot : ::Dot {
  uint weakness;
  uint hallucinogens;

  Default {
    DamageType "Poison";
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
    return (2.0/3.0) * (stacks)**(3.0/2.0) * 2.5;
  }

  override double GetDamage() {
    DEBUG("GetDamage: hallu=%d damage=%f health=%d", hallucinogens, GetTotalDamage(), owner.health);
    if (hallucinogens > 0 && GetTotalDamage() >= owner.health && !owner.bFRIENDLY) {
      DEBUG("Made the %s friendly!", owner.GetClassName());
      owner.bFRIENDLY = true;
      owner.bDONTHARMCLASS = false;
      owner.bDONTHARMSPECIES = false;
    }
    DEBUG("poison stacks=%f damage=%f", stacks, (stacks**0.5 / 2.0));
    stacks -= 0.2;
    return (stacks+0.2)**0.5 / 2.0; // poison damage scales with square root of remaining seconds
  }

  // Damage modifier for Weakness and Hallucinogens upgrades.
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (passive || damage <= 0 || weakness <= 0 || stacks <= 0) {
      return;
    }

    // Outgoing damage. Scale it down based on the number of poison stacks.
    // ...unless the monster is friendly, in which case it gets stronger.
    if (owner.bFRIENDLY) {
      newdamage = ceil(damage * (1.0 + 0.01 * stacks * hallucinogens));
    } else {
      newdamage = max(1, floor(damage * 0.99 ** (stacks * weakness)));
    }
    DEBUG("Weakness: %d -> %d", damage, newdamage);
  }

  override void CopyFrom(::Dot _src) {
    super.CopyFrom(_src);
    let src = ::PoisonDot(_src);
    self.weakness = max(self.weakness, src.weakness);
    self.hallucinogens = max(self.hallucinogens, src.hallucinogens);
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

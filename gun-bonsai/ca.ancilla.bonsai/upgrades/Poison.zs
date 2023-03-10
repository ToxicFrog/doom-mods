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

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("stacks", ""..level);
    fields.insert("softcap", ""..(level*10));
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

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("reduction", AsPercentDecrease(0.99 ** level));
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

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("increase", AsPercentIncrease(GetDamageFactor(level, 1)));
    fields.insert("armour", AsPercentDecrease(GetArmourFactor(level, 1)));
    fields.insert("poisonrate", AsPercent(GetPoisonFactor(level)));
  }

  static double GetDamageFactor(uint level, double stacks) {
    return 1.0 + 0.01 * level * stacks;
  }
  static double GetArmourFactor(uint level, double stacks) {
    return (0.95 ** level) ** stacks;
  }
  static double GetPoisonFactor(uint level) {
    return 0.5 ** level;
  }
}

class ::Putrefaction : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_POISON; }
  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    double stacks = ::Dot.CountStacks(target, "::PoisonDot");
    DEBUG("killed %s, poison stacks=%d", TAG(target), stacks);
    if (stacks <= 0) return;

    let aux = ::Putrefaction::Aux(target.Spawn("::Putrefaction::Aux", target.pos));
    aux.target = player;
    aux.level = max(stacks - (stacks * 0.5**level), 1);
    DEBUG("spawned putrefaction cloud with level=%d", aux.level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::Weakness", "::Hallucinogens");
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("transfer", AsPercent(1.0 - 0.5**level));
    fields.insert("range", "3m");
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
    static const string hallu[] = { "red", "orange", "yellow", "green1", "blue", "purple" };
    if (!owner.bFRIENDLY)
      return colours[random(0,2)];
    else
      return hallu[random(0,5)];
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
      owner.A_SetFriendly(true);
      owner.bDONTHARMCLASS = false;
      owner.bDONTHARMSPECIES = false;
    }
    DEBUG("poison stacks=%f damage=%f", stacks, (stacks**0.5 / 2.0));
    double factor = 1.0;
    if (owner.bFRIENDLY) factor = ::Hallucinogens.GetPoisonFactor(hallucinogens);
    double delta = 0.2 * factor;
    stacks -= delta;
    return ((stacks+delta)**0.5 / 2.0) * factor; // poison damage scales with square root of remaining seconds
  }

  // Damage modifier for Weakness and Hallucinogens upgrades.
  // TODO: there should be some visual effect when hallu kicks in other than the
  // particles changing colour, so the player knows when to switch targets even
  // if they don't have DamNums installed.
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (owner.bFRIENDLY && damageType != "Poison") {
      // Hallucinating enemies have special damage rules.
      newdamage = ModifyDamageWhileHallucinating(damage, passive, source);
      DEBUG("Hallucinating: %d damage (pasv=%d) -> %d", damage, passive, newdamage);
      return;
    }
    // No effect on incoming damage or if poison has worn off or does not have
    // any levels in Weakness.
    if (passive || damage <= 0 || weakness <= 0 || stacks <= 0) {
      return;
    }
    // Scale damage down based on total stacks + weakness level.
    newdamage = max(1, floor(damage * 0.99 ** (stacks * weakness)));
    DEBUG("Weakness: %d -> %d", damage, newdamage);
  }

  // Called for damage dealt or received while under the influence of Hallucinogens.
  // Incoming damage is reduced and outgoing damage to non-players is increased.
  int ModifyDamageWhileHallucinating(int damage, bool passive, Actor source) {
    if (source.player) {
      // Hallucinating enemies deal and receive 1 damage vs. players.
      return 1;
    }

    if (passive) {
      // Incoming damage reduced
      return max(1, floor(damage * ::Hallucinogens.GetArmourFactor(hallucinogens, stacks)));
    } else {
      // Outgoing damage increased.
      return ceil(damage * ::Hallucinogens.GetDamageFactor(hallucinogens, stacks));
    }
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

  void Spread() {
    Array<Actor> targets;
    // TODO: scale blast radius with level?
    TFLV::Util.MonstersInRadius(self, 100, targets);
    for (uint i = 0; i < targets.size(); ++i) {
      ::Dot.GiveStacks(self.target, targets[i], "::PoisonDot", level, level);
    }
  }

  States {
    Spawn:
      LPBX ABABABCBCBCDCDCDEE 7 Spread();
      STOP;
  }
}

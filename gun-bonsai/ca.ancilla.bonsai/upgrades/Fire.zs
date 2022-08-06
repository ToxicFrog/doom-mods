// The fire elemental upgrade tree.
//
// APPRENTICE: INCENDIARY SHOTS
// Burns enemies down to a certain % of health.
// More stacks increase both the burn rate, and the minimum %.
// Stack application depends on damage dealt.
// Leveling increases the softcap.
//
// JOURNEYMAN: BURNING TERROR
//
// Reduces the health % at which fire stops burning. Cannot reduce it to 0 --
// diminishing returns.
//
// MASTER: CONFLAGRATION
// Enemies with sufficient fire stacks on them will spread them to nearby enemies.
// More stacks increases the cap for spread fire.
// Higher levels increase the spread speed and radius.
//
// MASTER: INFERNAL KILN
// Attacking burning enemies gives you a temporary damage/resistance bonus.
#namespace TFLV::Upgrade;
#debug off

class ::IncendiaryShots : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_FIRE; }
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    // Apply stacks equal to 20% of damage.
    // Softcap == level -- since fire never burns out we can afford to set it pretty low
    // and gradually turn up the heat.
    ::Dot.GiveStacks(player, target, "::FireDot", damage*0.2, level);
  }
}

class ::BurningTerror : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_FIRE; }
  override string DotType() { return "::FireDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::FireDot(dot_item).terror = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasIntermediatePrereq(info, "::IncendiaryShots");
  }
}

class ::Conflagration : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_FIRE; }
  override string DotType() { return "::FireDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::FireDot(dot_item).spread = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::BurningTerror", "::InfernalKiln");
  }
}

class ::InfernalKiln : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_FIRE; }
  double hardness;

  // Dealing damage to a burning enemy adds "kiln points" equal to 1% of the
  // amount of damage dealt times the number of stacks.
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    DEBUG("Kiln: hardness %f", hardness);
    hardness += ::Dot.CountStacks(target, "::FireDot") * 0.01 * damage;
    DEBUG("Kiln:  -> %f", hardness);
  }

  override void Tick(Actor owner) {
    if (hardness > 0) hardness -= 1.0/35.0;
  }

  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    // Adds damage equal to your level of Kiln * 2.
    if (hardness <= 0) return damage;
    DEBUG("Kiln: %f + %f (%f)", damage, level*2.0, hardness);
    damage += level*2.0;
    // hardness--;
    return damage;
  }

  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    // Blocks damage equal to your level of Kiln * 2.
    if (hardness <= 0) return damage;
    DEBUG("Kiln: %f - %f (%f)", damage, level*2.0, hardness);
    damage -= min(damage, level*2.0);
    // hardness--;
    return damage;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::BurningTerror", "::Conflagration");
  }
}

// Fire will try to do this proportion of the target's health in damage.
const BASE_FIRE_FACTOR = 0.5;
const HEAT_FACTOR = 0.9;
const DAMAGE_PER_STACK = 4.0; // per dot tick, so multiply by 5 to get DPS

class ::FireDot : ::Dot {
  bool burning;
  uint terror; // level of Searing Heat upgrade
  uint spread; // level of Conflagration upgrade

  Default {
    DamageType "Fire";
  }

  override string GetParticleColour() {
    static const string hot[] = { "red", "orangered", "orange", "yellow", "lightyellow" };
    static const string cold[] = { "red4", "orangered4", "orange4", "orangered4", "red4" };
    if (burning)
      return hot[random(0,4)];
    else
      return cold[random(0,4)];
  }

  override double GetParticleZV() {
    return 0.1;
  }

  override double GetDamage() {
    double goal = owner.SpawnHealth() * BASE_FIRE_FACTOR * HEAT_FACTOR ** (stacks-1);
    double total_damage = owner.health - goal;

    if (spread > 0)
      SpreadFlames();

    if (total_damage <= 0.0) {
      burning = false;
      return 0.0;
    }

    DEBUG("fire damage, hp=%d, goal=%f, total=%f, damage=%f",
      owner.health, goal, total_damage, clamp(total_damage/10.0, 0.2, stacks));

    burning = true;
    double damage = min(total_damage/10.0+terror/5, stacks * DAMAGE_PER_STACK);
    if (terror > 0) DoTerror(damage);
    return damage;
  }

  // Burning Terror implementation.
  void DoTerror(double damage) {
    // If the target's health is below a certain amount -- which scales with
    // both levels of terror and stacks of fire -- it flees.
    if (damage >= 1) {
      let missing_health = 1 - double(owner.health)/owner.SpawnHealth();
      if (missing_health >= 0.7 ** (stacks+terror)) {
        owner.bFRIGHTENED = true;
      }
    } else if (random(0.0, 1.0) > damage) {
      owner.bFRIGHTENED = false;
    }

    // Independent of whether it's fleeing, it has a chance to enter pain based
    // on the amount of fire damage it's taking and the level of terror.
    double nopain = (0.95 - damage/owner.SpawnHealth()) ** (terror*2);
    if (random(0.0, 1.0) > nopain) {
      DEBUG("Terror! chance was %.2f", 1-nopain);
      owner.TriggerPainChance("Fire", true);
    }
  }

  // Conflagration implementation.
  // Drop a fire-spreading entity that sets everything around it on fire.
  void SpreadFlames() {
    let aux = ::Conflagration::Aux(Spawn("::Conflagration::Aux", owner.pos));
    aux.target = self.target;
    aux.spread = self.spread;
    aux.stacks = self.stacks;
    aux.terror = self.terror;
    aux.range = owner.radius;
  }
}

class ::Conflagration::Aux : Actor {
  double stacks;
  uint terror; // level of Burning Terror upgrade
  uint spread; // level of Conflagration upgrade
  uint range; // radius of parent actor

  Default {
    RenderStyle "Translucent";
    Alpha 0.4;
    +NODAMAGETHRUST;
    +NOGRAVITY;
  }

  override void PostBeginPlay() {
    DEBUG("conflagration running");
    self.SetStateLabel("Spawn");
  }

  uint GetRange() {
    DEBUG("GetRange: %d", 32 + spread*16 + stacks);
    return range * (1.0 + 0.5*spread + 0.1*stacks);
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    let fdot = ::FireDot(::Dot.GiveStacks(self.target, target, "::FireDot", 0, 1));
    if (fdot.stacks < self.stacks) {
      fdot.AddStacks(1, spread);
      DEBUG("Transfer: %s with softcap %d -> %.1f stacks", TAG(target), spread, fdot.stacks);
    }
    fdot.terror = max(fdot.terror, self.terror);
    fdot.spread = max(fdot.spread, self.spread - 1);
    return 0;
  }

  States {
    Spawn:
      LFIR G 7 NoDelay A_Explode(1, GetRange(), XF_NOSPLASH, false, GetRange());
      LFIR H 7;
      STOP;
  }
}

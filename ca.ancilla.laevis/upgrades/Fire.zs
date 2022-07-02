// The fire elemental upgrade tree.
//
// APPRENTICE: INCENDIARY SHOTS
// Burns enemies down to a certain % of health.
// More stacks increase the burn rate, but not the minimum %.
// Stack application depends on damage dealt.
// Leveling applies stacks faster and increases the softcap.
//
// JOURNEYMAN: SEARING HEAT
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

class ::IncendiaryShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    // TODO: softcap support
    ::Dot.GiveStacks(player, target, "::FireDot", level*damage*0.2);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }
}

class ::SearingHeat : ::DotModifier {
  override string DotType() { return "::FireDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::FireDot(dot_item).heat = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::IncendiaryShots") > info.upgrades.Level("::SearingHeat");
  }
}

class ::Conflagration : ::DotModifier {
  override string DotType() { return "::FireDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::FireDot(dot_item).spread = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::SearingHeat") > info.upgrades.Level("::Conflagration")
      && info.upgrades.Level("::InfernalKiln") == 0;
  }
}

class ::InfernalKiln : ::BaseUpgrade {
  double hardness;

  // Dealing damage to a burning enemy adds "kiln points" equal to 1% of the
  // amount of damage dealt times the number of stacks.
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    DEBUG("Kiln: hardness %f", hardness);
    hardness += ::Dot.CountStacks(target, "::FireDot") * 0.01 * damage;
    DEBUG("Kiln:  -> %f", hardness);
  }

  override void Tick() {
    if (hardness > 0) hardness -= 1.0/35.0;
  }

  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    // Adds damage equal to your level of Kiln * 2, and uses up 1 point.
    if (hardness <= 0) return damage;
    DEBUG("Kiln: %f + %f (%f)", damage, level*2.0, hardness);
    damage += level*2.0;
    hardness--;
    return damage;
  }

  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    // Blocks damage equal to your level of Kiln * 2, and uses up 1 point.
    if (hardness <= 0) return damage;
    DEBUG("Kiln: %f - %f (%f)", damage, level*2.0, hardness);
    damage -= min(damage, level*2.0);
    hardness--;
    return damage;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::SearingHeat") > info.upgrades.Level("::InfernalKiln")
      && info.upgrades.Level("::Conflagration") == 0;
  }
}

// Fire will try to do this proportion of the target's health in damage.
const BASE_FIRE_FACTOR = 0.5;
const HEAT_FACTOR = 0.8;
const DAMAGE_PER_STACK = 1.0; // per dot tick, so multiply by 5 to get DPS

class ::FireDot : ::Dot {
  bool burning;
  uint heat; // level of Searing Heat upgrade
  uint spread; // level of Conflagration upgrade

  Default {
    DamageType "Fire";
    +INCOMBAT; // Laevis recursion guard
    +NODAMAGETHRUST;
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
    double goal = owner.SpawnHealth() * BASE_FIRE_FACTOR * (HEAT_FACTOR ** heat);
    double total_damage = owner.health - goal;

    if (total_damage <= 0.0) {
      burning = false;
      return 0.0;
    }

    if (spread > 0)
      SpreadFlames();

    DEBUG("fire damage, hp=%d, goal=%f, total=%f, damage=%f",
      owner.health, goal, total_damage, clamp(total_damage/10.0, 0.2, stacks));

    burning = true;
    return min(total_damage/10.0, stacks);
  }

  // Conflagration implementation.
  // Drop a fire-spreading entity that sets everything around it on fire.
  void SpreadFlames() {
    // At level 1 we spread half the heat, at level 2 75%, etc.
    let spread_amount = ceil(stacks * (1.0 - 0.5 ** spread));
    DEBUG("SpreadFlames: %d -> %d", stacks, spread_amount);
    let aux = ::Conflagration::Aux(Spawn("::Conflagration::Aux", owner.pos));
    aux.target = self.target;
    aux.spread = self.spread;
    aux.stacks = self.stacks;
    aux.heat = self.heat;
  }
}

class ::Conflagration::Aux : Actor {
  uint stacks;
  uint heat; // level of Searing Heat upgrade
  uint spread; // level of Conflagration upgrade

  Default {
    RenderStyle "Translucent";
    Alpha 0.4;
    +NODAMAGETHRUST;
    +NOGRAVITY;
    +INCOMBAT; // Laevis recursion guard
  }

  override void PostBeginPlay() {
    DEBUG("conflagration running");
    self.SetStateLabel("Spawn");
  }

  uint GetRange() {
    DEBUG("GetRange: %d", 32 + spread*16 + stacks);
    return 32 + spread*16 + stacks;
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    DEBUG("Transfer: %d to %s", stacks, TFLV::Util.SafeCls(target));
    let fdot = ::FireDot(::Dot.GiveStacks(self.target, target, "::FireDot", 1, stacks));
    fdot.heat = max(fdot.heat, self.heat);
    fdot.spread = max(fdot.spread, self.spread - 1);
    DEBUG("Dot added: stacks=%d heat=%d spread=%d", fdot.stacks, fdot.heat, fdot.spread);
    return 0;
  }

  States {
    Spawn:
      LFIR G 7 NoDelay A_Explode(1, GetRange(), XF_NOSPLASH, false, GetRange());
      LFIR H 7;
      STOP;
  }
}

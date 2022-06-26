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

class ::IncendiaryShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    // TODO: softcap support
    ::Dot.GiveStacks(player, target, "::FireDot", level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }
}

class ::SearingHeat : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    let fire = ::FireDot(target.FindInventory("::FireDot"));
    if (!fire) return; // unlikely -- IncendiaryShots should have already applied fire
    fire.heat = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::IncendiaryShots") > 1;
  }
}

class ::Conflagration : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    let fire = ::FireDot(target.FindInventory("::FireDot"));
    if (!fire) return; // unlikely -- IncendiaryShots should have already applied fire
    fire.spread = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::IncendiaryShots") > 2
      && info.upgrades.Level("::SearingHeat") > 1
      && info.upgrades.Level("::InfernalForge") == 0;
  }
}

class ::InfernalForge : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    // TODO: install buff in player
    return;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return false;
    return info.upgrades.Level("::IncendiaryShots") > 2
      && info.upgrades.Level("::SearingHeat") > 1
      && info.upgrades.Level("::Conflagration") == 0;
  }
}

// Fire will try to do this proportion of the target's health in damage.
const BASE_FIRE_FACTOR = 0.5;
const HEAT_FACTOR = 0.8;
const DAMAGE_PER_STACK = 1.0; // per dot tick, so multiply by 5 to get DPS
#debug on

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
      owner.health, goal, total_damage, clamp(total_damage/10.0, 0.2, amount));

    burning = true;
    return min(total_damage/10.0, amount);
  }

  // Conflagration implementation.
  // Drop a fire-spreading entity that sets everything around it on fire.
  void SpreadFlames() {
    // At level 1 we spread half the heat, at level 2 75%, etc.
    let spread_amount = ceil(amount * (1.0 - 0.5 ** spread));
    DEBUG("SpreadFlames: %d -> %d", amount, spread_amount);
    let aux = ::Conflagration::Aux(Spawn("::Conflagration::Aux", owner.pos));
    aux.target = self.target;
    aux.spread = self.spread;
    aux.amount = self.amount;
    aux.heat = self.heat;
  }
}

class ::Conflagration::Aux : Actor {
  uint amount;
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
    DEBUG("GetRange: %d", 32 + spread*16 + amount);
    return 32 + spread*16 + amount;
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    DEBUG("Transfer: %d to %s", amount, TFLV::Util.SafeCls(target));
    let fdot = ::FireDot(::Dot.GiveStacks(self.target, target, "::FireDot", 1, amount));
    fdot.heat = max(fdot.heat, self.heat);
    fdot.spread = max(fdot.spread, self.spread - 1);
    DEBUG("Dot added: amount=%d heat=%d spread=%d", fdot.amount, fdot.heat, fdot.spread);
    return 0;
  }

  States {
    Spawn:
      LFIR G 7 NoDelay A_Explode(1, GetRange(), XF_NOSPLASH, false, GetRange());
      LFIR H 7;
      STOP;
  }
}

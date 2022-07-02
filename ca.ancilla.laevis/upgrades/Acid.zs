// The acid (water) upgrade tree.
//
// APPRENTICE: CORROSIVE SHOTS
// Damage over time with the damage increasing the less health the enemy has.
// Faster damage uses up stacks faster.
// Stacks applied depends on AND IS CAPPED BASED ON weapon damage, so this works
// best with slow but powerful weapons.
//
// UPGRADE: ACID SPRAY
// Attacks that would exceed the acid stack cap instead spray the acid onto
// nearby enemies.
//
// MASTER: EXPLOSIVE REACTION
// Acidified enemies explode on death, dealing damage to their surroundings
// proportionate to their max HP and the amount of acid stacks left on them.
//
// MASTER: EMBRITTLEMENT
// Acidified enemies take increased damage from all non-acid sources, scaling
// with the number of acid stacks on them.
#namespace TFLV::Upgrade;
#debug on

class ::CorrosiveShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    let ad = ::AcidDot(::Dot.GiveStacks(player, target, "::AcidDot", 0));
    ad.damage_this_tick += damage;
    ad.level = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }
}

class ::AcidSpray : ::DotModifier {
  override string DotType() { return "::AcidDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::AcidDot(dot_item).splash = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::CorrosiveShots") > info.upgrades.Level("::AcidSpray");
  }
}

class ::Embrittlement : ::DotModifier {
  override string DotType() { return "::AcidDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::AcidDot(dot_item).embrittlement = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::AcidSpray") > info.upgrades.Level("::Embrittlement")
      && info.upgrades.Level("::ExplosiveReaction") == 0;
  }
}

class ::ExplosiveReaction : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    uint amount = ::Dot.CountStacks(target, "::AcidDot");
    if (amount <= 0) return;

    let aux = ::ExplosiveReaction::Aux(target.Spawn("::ExplosiveReaction::Aux", target.pos));
    aux.target = player;
    aux.level = level;
    aux.stacks = amount;
    aux.hp = target.SpawnHealth();
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::AcidSpray") > info.upgrades.Level("::ExplosiveReaction")
      && info.upgrades.Level("::Embrittlement") == 0;
  }
}


// Poison DoT. Note that it burns one stack per dot tick, so 5 stacks == 1 second.
class ::AcidDot : ::Dot {
  uint damage_this_tick;
  uint level;
  uint splash;
  uint embrittlement;

  Default {
    DamageType "Acid";
    +INCOMBAT; // Laevis recursion guard
    +NODAMAGETHRUST;
  }

  // Custom states so that we can tick down damage_this_tick immediately.
  States {
    Dot:
      TNT1 AAAAAAA 1 AcidTick();
      TNT1 A 0 TickDot();
      TNT1 A 0 SpawnParticles();
      LOOP;
  }

  void AcidTick() {
    if (damage_this_tick > 0) {
      // We're done applying stacks this tick.
      // Trim down the number of stacks to the actual cap based on level.
      double cap = level * damage_this_tick * 0.5;
      DEBUG("acid: stacks=%f, damage=%f, cap=%f", stacks, damage_this_tick, cap);
      if (stacks < cap) {
        double diff = cap - stacks;
        stacks = cap;
        cap -= diff;
      }
      DEBUG("acid: now stacks=%f, cap=%f", stacks, cap);
      // If there's excess stacks and we have Acid Spray, proc it.
      if (cap > 0 && splash > 0) {
        DEBUG("Acid Spray! %d", stacks);
        let aux = ::AcidSpray::Aux(owner.Spawn("::AcidSpray::Aux", owner.pos));
        aux.level = self.splash;
        aux.amount = cap;
      }
      damage_this_tick = 0;
    }
  }

  override string GetParticleColour() {
    static const string colours[] = { "purple", "purple1", "blue1" };
    return colours[random(0,2)];
  }

  override double GetParticleZV() {
    return -0.1;
  }

  override double GetDamage() {
    // We want acid damage to start out as almost nothing (say 0.5 dps) but
    // below 50% HP accelerate rapidly.
    double hp = double(owner.Health) / owner.SpawnHealth();
    double damage = (1.0 - (2.0 * atan(hp*90.0))/180.0) * 5;
    DEBUG("acid hp=%f stacks=%f damage=%f", hp, stacks, damage);
    damage = min(damage, stacks);
    DEBUG("actual damage=%f", damage);
    stacks -= damage;
    return damage;
  }

  // Damage modifier for Embrittlement upgrade.
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (!passive || damage <= 0 || embrittlement <= 0 || amount <= 0) {
      return;
    }
    if (damageType == "Acid") return;

    // Boost incoming damage based on the number of acid stacks.
    newdamage = ceil(damage * (1.0 + 0.01 * amount * embrittlement));
  }
}

class ::ExplosiveReaction::Aux : Actor {
  uint level;
  uint stacks;
  uint hp;

  Default {
    DamageType "Acid";
    +NODAMAGETHRUST;
  }

  States {
    Spawn:
      LACD A 5 Bright NoDelay A_Explode(hp * stacks * 0.01, 100 + level*50, XF_NOSPLASH, false, level*10);
      LACD BCDE 5 Bright;
      STOP;
  }
}

class ::AcidSpray::Aux : Actor {
  uint level;
  double amount;

  Default {
    RenderStyle "Translucent";
    Alpha 0.4;
    +NODAMAGETHRUST;
    +NOGRAVITY;
    +INCOMBAT; // Laevis recursion guard
  }

  uint GetRange() {
    DEBUG("GetRange: %d", 32 + level*16);
    return 32 + level*16;
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    // This can exceed the acid cap!
    // TODO: respect cap
    // TODO: split evenly among nearby enemies rather than copying to them
    DEBUG("Acid Spray spreading: %f", amount);
    ::Dot.GiveStacks(self.target, target, "::AcidDot", amount);
    return 0;
  }

  States {
    Spawn:
      LACD A 5 Bright NoDelay A_Explode(1, GetRange(), XF_NOSPLASH, false, GetRange());
      LACD BCDE 5 Bright;
      STOP;
  }
}

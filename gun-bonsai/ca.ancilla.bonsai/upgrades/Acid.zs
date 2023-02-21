// The acid (water) upgrade tree.
//
// APPRENTICE: CORROSIVE SHOTS
// Damage over time with the damage increasing the less health the enemy has.
// Faster damage uses up stacks faster.
// Stacks applied depends on AND IS CAPPED BASED ON weapon damage, so this works
// best with slow but powerful weapons.
//
// UPGRADE: CONCENTRATED ACID
// Activation threshold & stack to damage conversion ratio improve.
//
// MASTER: ACID SPRAY
// Attacks that would exceed the acid stack cap instead spray the acid onto
// nearby enemies.
//
// MASTER: EMBRITTLEMENT
// Acidified enemies take increased damage from all non-acid sources, scaling
// with the number of acid stacks on them. Enemies with less HP than acid
// stacks die instantly.

#namespace TFLV::Upgrade;
#debug off

class ::CorrosiveShots : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_ACID; }
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    let ad = ::AcidDot(::Dot.GiveStacks(player, target, "::AcidDot", 0));
    ad.damage_this_tick += damage;
    ad.level = level;
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("conversion", AsPercent(0.5 + 0.1*level));
    fields.insert("min-damage", ""..level);
    fields.insert("max-damage", ""..(10*level));
  }
}

class ::ConcentratedAcid : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_ACID; }
  override string DotType() { return "::AcidDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::AcidDot(dot_item).concentration = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasIntermediatePrereq(info, "::CorrosiveShots");
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("efficiency", AsPercentIncrease(1.0/0.9**level));
    fields.insert("threshold", AsPercent(0.5 * (2.0 - 0.8 ** level)));
  }
}

class ::AcidSpray : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_ACID; }
  override string DotType() { return "::AcidDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::AcidDot(dot_item).splash = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::ConcentratedAcid", "::Embrittlement");
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("radius", (2+level).."m");
    fields.insert("cap-percent", AsPercent(0.2*level));
  }
}

class ::Embrittlement : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_ACID; }
  override string DotType() { return "::AcidDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::AcidDot(dot_item).embrittlement = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::ConcentratedAcid", "::AcidSpray");
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damage-increase", AsPercentIncrease(1.0 + level*0.01));
    fields.insert("instakill", AsPercent(1/(1+0.1*level)));
  }
}

// Acid DoT. Note that it burns one stack per dot tick, so 5 stacks == 1 second.
class ::AcidDot : ::Dot {
  uint damage_this_tick;
  uint level;
  uint concentration;
  uint splash;
  uint embrittlement;

  override void CopyFrom(::Dot _src) {
    super.CopyFrom(_src);
    let src = ::AcidDot(_src);
    self.concentration = max(self.concentration, src.concentration);
    self.splash = max(self.splash, src.splash);
    self.embrittlement = max(self.embrittlement, src.embrittlement);
  }

  Default {
    DamageType "Acid";
  }

  // Custom states so that we can tick down damage_this_tick immediately.
  States {
    Dot:
      TNT1 AAAAAAA 1 { DamageToStacks(); DrawVFX(); }
      TNT1 A 0 TickDot();
      LOOP;
  }

  void DamageToStacks() {
    if (damage_this_tick > 0) {
      // We've tallied up all the damage taken this tick.
      // Convert it into actual acid stacks at a rate of 50%+10%/level of damage dealt,
      // and a softcap equivalent to the damage dealt.
      double new_stacks = damage_this_tick * (0.5 + 0.1 * level);
      double cap = damage_this_tick;
      DEBUG("acid: stacks=%f, damage=%f, added=%f", stacks, damage_this_tick, new_stacks);

      let old_stacks = stacks;
      AddStacks(new_stacks, cap);
      // We tried to apply new_stacks, the amount actually added is stacks - old_stacks.
      // So our surplus is:
      let surplus = new_stacks - (stacks - old_stacks);

      DEBUG("acid: now stacks=%f, surplus=%f", stacks, surplus);

      // If there's excess stacks and we have Acid Spray, proc it.
      if (surplus > 1 && splash > 0) {
        DEBUG("Acid Spray! %d", surplus);
        let aux = ::AcidSpray::Aux(owner.Spawn("::AcidSpray::Aux", owner.pos));
        // Copy parameters from self.
        aux.target = self.target;
        aux.level = self.level;
        aux.splash = self.splash;
        aux.concentration = self.concentration;
        // Splash-specific parameters.
        aux.stacks = surplus;
        aux.softcap = cap * self.splash * 0.2;
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
    // We want acid damage to be slow to start and accelerate once the target
    // is below 50% HP.
    // We also want to raise that 50% limit slightly for each acid stack
    // on the target.
    // Say above 50% HP it just does [level] DPS.
    double hp = double(owner.Health) / owner.SpawnHealth();
    // At concentration=0 this gives us a threshold of 0.5,
    // approaching 1.0 as concentration increases
    double threshold = 0.5 * (2.0 - (0.8 ** concentration));
    double damage;
    if (hp > threshold) {
      damage = 0.2 * level; // 5 dot ticks per second
    } else {
      // Below that it scales up to 10*level
      damage = max(0.2, (1-hp/threshold)*2*max(1,level));
    }
    DEBUG("acid hp=%f threshold=%f stacks=%f damage=%f", hp, threshold, stacks, damage);
    damage = min(damage, stacks);
    DEBUG("actual damage=%f", damage);
    stacks -= damage * (0.9 ** concentration);
    return damage;
  }

  // Return the HP threshold at which enemies will be instakilled.
  // This is number of stacks, scaled by concentration bonus and then increased
  // by 10% per Embrittlement level.
  uint InstakillThreshold() {
    return stacks / (0.9**concentration) * (1 + 0.1*embrittlement);
  }

  // Damage modifier for Embrittlement upgrade.
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (!passive || damage <= 0 || embrittlement <= 0 || amount <= 0) {
      return;
    }

    if (damageType == "Acid") {
      DEBUG("Instakill? %d < %d", owner.health, InstakillThreshold());
      if (owner.health < InstakillThreshold()) newdamage = owner.health+1;
      return;
    }

    // Boost incoming damage based on the number of acid stacks.
    newdamage = ceil(damage * (1.0 + 0.01 * amount * embrittlement));
  }
}

class ::AcidSpray::Aux : Actor {
  double stacks; // amount of acid to stack on each target
  double softcap; // softcap to apply to targets.
  uint level, concentration, splash; // copied from original dot

  Default {
    RenderStyle "Translucent";
    Alpha 0.2;
    +NODAMAGETHRUST;
    +NOGRAVITY;
  }

  uint GetRange() {
    return 64 + level*32;
  }

  void SpreadTo(Actor target) {
    let acid = ::AcidDot(::Dot.GiveStacks(self.target, target, "::AcidDot", stacks, softcap));
    acid.level = max(acid.level, level);
    acid.concentration = max(acid.concentration, concentration);
    acid.splash = max(acid.splash, splash);
  }

  void Spread() {
    Array<Actor> targets;
    TFLV::Util.MonstersInRadius(self, GetRange(), targets);
    for (uint i = 0; i < targets.size(); ++i) {
      SpreadTo(targets[i]);
    }
  }

  States {
    Spawn:
      LACD A 5 Bright NoDelay Spread();
      LACD BCDE 5 Bright;
      STOP;
  }
}

// The lightning (air) upgrade tree.
//
// APPRENTICE: SHOCKING INSCRIPTION
// Attacks stun enemies. Stun duration scales with level and weapon damage.
//
// UPGRADE: REVIVIFICATION
// Slain enemies have chance to rise as your minions based on the number of
// lightning stacks on them.
//
// MASTER: CHAIN LIGHTNING
// Enemies killed with lightning stacks on them chain lightning to nearby
// enemies. Total jump count scales with level; damage scales with total number
// of enemies caught in the chain.
//
// MASTER: THUNDERBOLT
// Capping out the lightning stacks on a target converts all of them into damage.
#namespace TFLV::Upgrade;

class ::ShockingInscription : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    // Stack 20% of damage * 200ms of stun, softcap at 1s/level
    let zap = ::ShockDot(::Dot.GiveStacks(
      player, target, "::ShockDot", level*damage*0.2, level*5));
    zap.cap = level*5;
  }
}

class ::Revivification : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  override string DotType() { return "::ShockDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::ShockDot(dot_item).revive = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasIntermediatePrereq(info, "::ShockingInscription");
  }
}

class ::ChainLightning : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  override string DotType() { return "::ShockDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::ShockDot(dot_item).chain = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::Revivification", "::Thunderbolt");
  }
}

class ::Thunderbolt : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  override string DotType() { return "::ShockDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    let shock = ::ShockDot(dot_item);
    DEBUG("Thunderbolt: %d/%d", shock.stacks, shock.cap);
    // Thunderbolt triggers once you exceed the softcap by 2x
    if (shock.stacks > shock.cap*2) {
      // Base damage is 10% of the target's max health per level, with diminishing
      // returns.
      let damage = target.SpawnHealth() * (1.0 - 0.9**level);
      DEBUG("Target mhp=%d, bolt=%d", target.SpawnHealth(), damage);
      // It then gets a bonus of +1% damage per stack, minimum 1 point of damage
      // per stack.
      damage += max(shock.stacks, damage * 0.01 * shock.stacks);
      DEBUG("Damage after stack bonus=%d", damage);

      let aux = ::Thunderbolt::Aux(target.Spawn("::Thunderbolt::Aux", target.pos));
      aux.target = player;
      aux.tracer = target;
      target.DamageMobj(aux, player, damage, "Electric", DMG_THRUSTLESS);
      shock.stacks = 0;
    }
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::Revivification", "::ChainLightning");
  }
}

// Lightning "dot". Doesn't actually do damage over time, but has some other effects.
class ::ShockDot : ::Dot {
  uint revive; // Revivification level
  uint chain; // Chain Lightning level
  uint cap; // Cap used for Thunderbolt triggers

  Default {
    // This matches Hexen's lightning weapons.
    DamageType "Electric";
  }

  // TODO: rework particles entirely for lightning, it should produce constant
  // outward "zaps".
  override string GetParticleColour() {
    static const string colours[] = { "azure", "deepskyblue", "lightskyblue", "ghostwhite" };
    return colours[random(0,3)];
  }

  override double GetParticleZV() {
    return 0.001;
  }

  override void Tick() {
    owner.TriggerPainChance(self.damagetype, true);
    super.Tick();
  }

  override double GetDamage() {
    --stacks;
    return 0.0;
  }

  void MellGetTheElectrodes() {
    // Chance of staying dead is (100% - (0.2% per stack))^level
    let chance = (1.0 - stacks * 0.002) ** revive;
    if (frandom(0.0, 1.0) < chance) return;
    let aux = ::Revivification::Aux(self.Spawn("::Revivification::Aux", owner.pos));
    aux.target = self.target;
    aux.tracer = self.owner;
    aux.level = self.revive;
  }

  void ZapZap() {
    let pos = owner.pos;
    pos.z += owner.height/2;
    let aux = ::ChainLightning::Aux(self.Spawn("::ChainLightning::Aux", pos));
    aux.target = self.target;
    aux.level = self.chain; // determines max jumps
    aux.damage = owner.SpawnHealth() * (0.5 + 0.003 * stacks);
    aux.targets.push(owner);
    DEBUG("Chain lightning, base damage=%d", aux.damage);
    return;
  }

  override void OwnerDied() {
    // Trigger revivification & chain lightning.
    if (revive > 0) MellGetTheElectrodes();
    if (chain > 0) ZapZap();
  }
}

class ::Revivification::Aux : Actor {
  uint level;

  States {
    CheckRevive:
      TNT1 A 1 CheckRevive();
      LOOP;
  }

  override void PostBeginPlay() {
    self.SetStateLabel("CheckRevive");
  }

  void CheckRevive() {
    // Just in case.
    if (!tracer || !tracer.ResolveState("Raise")) {
      DEBUG("tracer vanished");
      Destroy();
      return;
    }
    // This might be temporary because e.g. there's something standing on it.
    if (!tracer.CanRaise()) return;

    // Attempt the actual resurrection.
    DEBUG("Raising %s by %s", tracer.GetTag(), target.GetTag());
    // We need to do this before we start wiggling its flags.
    if (!tracer.RaiseActor(tracer)) {
      Destroy(); return;
    }
    // Clear any dots on it.
    tracer.TakeInventory("::FireDot", 255);
    tracer.TakeInventory("::AcidDot", 255);
    tracer.TakeInventory("::PoisonDot", 255);
    tracer.TakeInventory("::ShockDot", 255);
    // Make it friendly and ethereal.
    tracer.master = self.target;
    tracer.bFRIENDLY = true;
    tracer.bSOLID = false;
    tracer.A_SetRenderStyle(1.0, STYLE_SHADED);
    tracer.SetShade("8080FF");

    // Give it the force that applies the buff to revivified minions.
    let buff = ::Revivification::AuxBuff(tracer.GiveInventoryType("::Revivification::AuxBuff"));
    if (buff) buff.level = self.level; // this can fail sometimes?
    Destroy();
  }
}

class ::Revivification::AuxBuff : Inventory {
  uint level;
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INVENTORY.IGNORESKILL;
    +INVENTORY.UNTOSSABLE;
    +INVENTORY.UNDROPPABLE;
    +INVENTORY.QUIET;
  }

  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (passive) {
      // 20% damage reduction per level with diminishing returns.
      newdamage = ceil(damage * (0.8 ** level));
    } else if (inflictor == owner.master) {
      // Only ever deal 1 damage to the player that raised you.
      newdamage = 1;
    } else {
      // Flat 20% damage bonus on the way out.
      newdamage = floor(damage * (1.0 + 0.2 * level));
    }
  }
}

class ::ChainLightning::Aux : Actor {
  Array<Actor> targets;
  uint next_target;
  uint level;
  uint jumps;
  double damage;

  property UpgradePriority: special1;
  Default {
    DamageType "Electric";
    ::ChainLightning::Aux.UpgradePriority ::PRI_ELEMENTAL;
  }

  States {
    Zap:
      // TODO: cool zappy ball lightning effect
      TNT1 A 5 Zap();
      LOOP;
  }

  string GetParticleColour() {
    static const string colours[] = { "azure", "deepskyblue", "lightskyblue", "ghostwhite" };
    return colours[random(0,3)];
  }

  void Zap() {
    if (jumps <= 0 || next_target == targets.size()) {
      DEBUG("Max jumps reached, zapping everything.");
      ZapAll();
      Destroy();
      return;
    }

    uint last_target = targets.size();
    DEBUG("Starting spread, last_target=%d, jumps left=%d",
      last_target, jumps);
    for (uint i = next_target; i < last_target; ++i) {
      ZapFrom(targets[i]);
    }
    next_target = last_target;
    --jumps;
  }

  void ZapFrom(Actor tgt) {
    self.Warp(tgt, 0, 0, tgt.height, 0, WARPF_NOCHECKPOSITION|WARPF_BOB);
    let range = tgt.radius * (3 + level);
    DEBUG("ZapFrom: %s @ [%d,%d,%d] range=%d",
      tgt.GetTag(), tgt.pos.x, tgt.pos.y, tgt.pos.z, range);
    self.tracer = tgt;
    self.A_Explode(1, range, XF_NOSPLASH|XF_EXPLICITDAMAGETYPE, false, range);
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    // Don't modify hits that aren't part of the initial sweep
    if (damagetype != "None") return damage;
    if (targets.find(target) != targets.size() || !target.bISMONSTER) {
      // Don't zap non-monsters, and don't zap the same thing twice
      DEBUG("Skipping %s", target.GetTag());
      return 0;
    }
    DEBUG("Chain lightning arcs to %s", target.GetTag());
    targets.push(target);
    ::Dot.GiveStacks(self.target, target, "::ShockDot", 5, 5);
    DrawZap(target);
    return 0;
  }

  // TODO: still not entirely happy about this VFX, it seems to consistently
  // aim low even with FAF_TOP.
  void DrawZap(Actor target) {
    let source = self.tracer;
    let range = source.Distance3D(target);
    A_Face(target, 0, 180, 0, 0, FAF_TOP, 0);
    // A_FaceTracer(0, 180, 0, 0, FAF_MIDDLE, 0);
    DEBUG("Draw zap from [%d,%d,%d] to [%d,%d,%d] range=%d",
      source.pos.x, source.pos.y, source.pos.z,
      target.pos.x, target.pos.y, target.pos.z,
      range);
    for (uint i = 0; i < 8; ++i) {
      self.A_CustomRailgun(
        0, 0, "", GetParticleColour(),
        RGF_SILENT|RGF_FULLBRIGHT|RGF_EXPLICITANGLE|RGF_CENTERZ,
        0, 3, // aim and jaggedness
        "None", // pufftype
        0, 0, //spread
        range, 35*2, // range and duration
        0.5, // particle spacing
        0.2 // drift speed
        );
    }
  }

  void ZapAll() {
    let damage = self.damage * (1.0 + 0.01 * (targets.size()-1));
    for (uint i = 0; i < targets.size(); ++i) {
      if (!targets[i] || targets[i].bCORPSE) continue;
      DEBUG("Chain lightning damaging %s (%d) for %d", targets[i].GetTag(), targets[i].health, damage);
      targets[i].DamageMobj(
        self, self.target, floor(damage), self.DamageType,
        DMG_THRUSTLESS | DMG_NO_ENHANCE);
    }
  }

  // This is a bit tricky.
  // We start by exploding at our current position. Every enemy caught in the
  // blast gets added to the targets array and we draw a lightning bolt to it.
  // We probably also want to draw a ball of lightning on each enemy we arc to.
  // Then we need to sleep for a few tics, then explode again at the position
  // of every enemy we just added to the targets array. Any new enemies get
  // added to the array, draw lightning to them, etc.
  // Continue until either next_target == targets.size() (meaning we've arced to
  // everything in range) or the number of arc steps matches the level.
  // We need to explode, and every living enemy hit by the explosion needs to
  // get a lightning marker.
  override void PostBeginPlay() {
    jumps = level;
    self.SetStateLabel("Zap");
  }
}

class ::Thunderbolt::Aux : Actor {
  property UpgradePriority: special1;

  Default {
    ::Thunderbolt::Aux.UpgradePriority ::PRI_ELEMENTAL;
  }

  string GetParticleColour() {
    static const string colours[] = { "azure", "deepskyblue", "lightskyblue", "ghostwhite" };
    return colours[random(0,3)];
  }

  override void PostBeginPlay() {
    DEBUG("Thunderbolt PostBeginPlay");
    // We clear the SHOOTABLE bit because otherwise the railgun shots we use
    // for the lightning effect are stopped by the bottom of the actor for
    // some reason.
    let shootable = tracer.bSHOOTABLE;
    tracer.bSHOOTABLE = false;
    for (uint i = 0; i < 16; ++i) {
      // Vertical floor-to-ceiling lightning bolt
      self.Warp(tracer,
        random(-tracer.radius/2, tracer.radius/2),
        random(-tracer.radius/2, tracer.radius/2),
        0, 0, WARPF_TOFLOOR);
      DEBUG("Thunderbolt @[%d,%d,%d]",
        pos.x, pos.y, pos.z);
      self.A_CustomRailgun(
        1, 0, "", GetParticleColour(),
        RGF_SILENT|RGF_FULLBRIGHT|RGF_EXPLICITANGLE|RGF_CENTERZ,
        0, 10, // aim and jaggedness
        "BulletPuff", // pufftype
        0, -90, //spread and pitch
        0, 35*2, // range and duration
        0.5, // particle spacing
        0.2 // drift speed
        );
      tracer.A_SpawnParticle(
        GetParticleColour(), SPF_FULLBRIGHT|SPF_RELVEL|SPF_RELACCEL,
        70, 10, random(0,360), // lifetime, size, angle
        0, 0, tracer.height/2, // position
        // random(-owner.radius, owner.radius), random(-owner.radius, owner.radius), random(0, owner.height),
        2, 0, 0, // v
        -2/35, 0, 0); // a
    }
    tracer.bSHOOTABlE = shootable;
  }
}

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
#debug off

class ::ShockingInscription : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    // Stack 20% of damage * 200ms of stun, softcap at 1s/level
    let zap = ::ShockDot(::Dot.GiveStacks(
      player, target, "::ShockDot", level*damage*0.2, level*5));
    zap.cap = level*5;
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damage-per-stack", string.format("%d", 1.0/(0.2*level/5.0)));
    fields.insert("softcap", level.."s");
  }
}

class ::Revivification : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  override string DotType() { return "::ShockDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::ShockDot(dot_item).revive = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::Thunderbolt", "::ChainLightning");
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("revive-chance", AsPercent(1.0 - 0.99 ** level));
    fields.insert("lifetime", (level*5).."s");
    fields.insert("damage-bonus", AsPercentIncrease(0.2*level));
    fields.insert("armour-bonus", AsPercentDecrease(0.8 ** level));
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

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("arc-count", ""..level);
    fields.insert("arc-range", (level*3).."m");
  }
}

class ::Thunderbolt : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  override string DotType() { return "::ShockDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::ShockDot(dot_item).thunderbolt = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasIntermediatePrereq(info, "::ShockingInscription");
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damage-percent", AsPercent(1.0 - 0.9**level));
    fields.insert("zap-cap", AsPercent(2 * 0.9**level));
  }
}

// Lightning "dot". Doesn't actually do damage over time, but has some other effects.
class ::ShockDot : ::Dot {
  uint revive; // Revivification level
  uint chain; // Chain Lightning level
  uint thunderbolt; // Thunderbolt level
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
    if (owner.health <= 0) return;
    if (gametic % 2) return;
    owner.tics++;
    super.Tick();
  }

  override double GetDamage() {
    // Thunderbolt triggers once you exceed the softcap by 2x; levels in thunderbolt
    // reduce this, making it easier to trigger
    if (thunderbolt && stacks > (cap*2) * (0.9 ** thunderbolt)) {
      Kaboom();
    } else {
      --stacks;
    }
    return 0.0;
  }

  void MellGetTheElectrodes() {
    // Chance of staying dead is (100% - (0.2% per stack))^level
    let chance = (1.0 - stacks * 0.01) ** revive;
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
    aux.tracer = owner;
    aux.target = self.target;
    aux.level = self.chain; // determines max jumps
    aux.damage = owner.SpawnHealth() * (0.5 + 0.003 * stacks);
    DEBUG("Chain lightning, base damage=%d", aux.damage);
    return;
  }

  void Kaboom() {
    // Base damage is 10% of the target's max health per level, with diminishing
    // returns.
    let damage = owner.SpawnHealth() * (1.0 - 0.9**thunderbolt);
    DEBUG("Target mhp=%d, bolt=%d", target.SpawnHealth(), damage);
    // It then gets a bonus of +1% damage per stack, minimum 1 point of damage
    // per stack.
    damage += max(stacks, damage * 0.01 * stacks);
    DEBUG("Damage after stack bonus=%d", damage);

    owner.Spawn("::Thunderbolt::VFX", owner.pos);
    owner.DamageMobj(self, self.target, damage, "Electric", DMG_THRUSTLESS);
    stacks = 0;
  }

  override void OwnerDied() {
    super.OwnerDied();
    // Trigger revivification & chain lightning.
    if (revive > 0) MellGetTheElectrodes();
    if (chain > 0) ZapZap();
  }

  override void CopyFrom(::Dot _src) {
    super.CopyFrom(_src);
    let src = ::ShockDot(_src);
    self.revive = max(self.revive, src.revive);
    self.chain = max(self.chain, src.chain);
    self.thunderbolt = max(self.thunderbolt, src.thunderbolt);
    self.cap = max(self.cap, src.cap);
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
    tracer.SetFriendPlayer(self.target.player);
    tracer.bSOLID = false;
    tracer.A_SetRenderStyle(1.0, STYLE_SHADED);
    tracer.SetShade("8080FF");
    if (tracer.CountsAsKill()) tracer.level.total_monsters--;
    tracer.bFRIENDLY = true;

    // Give it the force that applies the buff to revivified minions.
    let buff = ::Revivification::AuxBuff(tracer.GiveInventoryType("::Revivification::AuxBuff"));
    if (buff) buff.level = self.level; // this can fail sometimes?
    Destroy();
  }
}

class ::Revivification::AuxBuff : Inventory {
  uint level;
  uint timer;
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INVENTORY.IGNORESKILL;
    +INVENTORY.UNTOSSABLE;
    +INVENTORY.UNDROPPABLE;
    +INVENTORY.QUIET;
  }

  override void Tick() {
    super.Tick();
    ++timer;
    if (timer > 35 * (level+5)) {
      owner.A_Die("Lightning");
      Destroy();
    }
  }

  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (source is "PlayerPawn") {
      // Only ever deal or receive 1 damage to players.
      newdamage = min(1, damage);
      return;
    }

    // Reset lifetimer.
    timer = 0;
    if (passive) {
      // 20% damage reduction per level with diminishing returns.
      newdamage = ceil(damage * (0.8 ** level));
    } else {
      // Flat 20% damage bonus per level on the way out.
      newdamage = floor(damage * (1.0 + 0.2 * level));
    }
  }
}

class ::ChainLightning::Arc : Object play {
  // Actors defining the start and end of the arc.
  Actor from;
  Actor to;
  // Vectors locating those actors at the time the arc was prepared. If the
  // actors no longer exist these positions are used instead.
  Vector3 start;
  Vector3 end;
  // How many jumps were left in the chain when this arc was recorded. Used for
  // timing -- higher ttls display earlier.
  uint ttl;

  void RecordPositions(Actor from, Actor to, uint ttl) {
    self.from = from; self.to = to; self.ttl = ttl;
    UpdatePositions();
  }

  // If our start/end actors still exist, update our positions to match them.
  void UpdatePositions() {
    if (self.from) {
      self.start = self.from.pos;
      self.start.z += self.from.height/2;
    }
    if (self.to) {
      self.end = self.to.pos;
      self.end.z += self.to.height/2;
    }
  }
}

class ::ChainLightning::Aux : Actor {
  Array<Actor> targets;
  Array<::ChainLightning::Arc> arcs;
  uint next_target;
  uint level;
  uint jumps;
  double damage;

  property UpgradePriority: weaponspecial;
  Default {
    DamageType "Electric";
    // About one caco. Used as the default for targets that disappear before
    // we can arc through them.
    Radius 32;
    ::ChainLightning::Aux.UpgradePriority ::PRI_ELEMENTAL;
  }

  States {
    Zap:
      TNT1 A 7 Zap();
      LOOP;
  }

  // Immediately on PostBeginPlay, we find everything that we can arc to and
  // record its identity and position in the arcs array. The targets array is
  // used for bookkeeping to make sure we don't form loops.
  override void PostBeginPlay() {
    self.Spawn("::ChainLightning::VFX", self.pos);
    jumps = level;
    if (self.tracer) {
      targets.push(self.tracer);
      FindTargets(self.tracer, self.level);
    } else {
      // Originating actor disappeared (gibbed?). Use ourself as the start point
      // instead.
      FindTargets(self, self.level);
    }
    self.SetStateLabel("Zap");
  }

  // Recursively find everything around the victim we can arc to within max_jumps.
  // The victim MUST exist; we guarantee this by doing everything within a single
  // tic, so anything found by A_Explode() will still exist when we recurse.
  // Populates the targets array with all the targets found, and the arcs array
  // with all the lightning arcs between them.
  void FindTargets(Actor victim, uint max_jumps) {
    if (max_jumps <= 0) return;

    self.warp(victim, 0, 0, victim.height/2, 0, WARPF_NOCHECKPOSITION|WARPF_BOB);
    DEBUG("FindTargets: %s [ttl=%d] (%d,%d,%d) @ (%d,%d,%d)",
      TAG(victim), max_jumps,
      victim.pos.x, victim.pos.y, victim.pos.z,
      self.pos.x, self.pos.y, self.pos.z);
    uint radius = max(victim.radius, 32) * (3+level);
    uint next_target = targets.size();
    // We are now in position, so explode to find everything nearby.
    // DoSpecialDamage will add them all to the targets array.
    // XF_EXPLICITDAMAGETYPE with no explicit damage type defaults to None.
    A_Explode(1, radius, XF_NOSPLASH|XF_EXPLICITDAMAGETYPE, false, radius);
    // Collect all the new targets, if any, and record the arcs to them.
    DEBUG("Processing %d new targets", targets.size() - next_target);
    for (uint i = next_target; i < targets.size(); ++i) {
      let arc = new("::ChainLightning::Arc");
      arc.RecordPositions(victim, targets[i], max_jumps);
      arcs.push(arc);
      DEBUG("Recorded arc %d [ttl=%d] from %s (%d,%d,%d) to %s (%d,%d,%d)",
        arcs.size()-1, max_jumps,
        TAG(victim), arc.start.x, arc.start.y, arc.start.z,
        TAG(targets[i]), arc.end.x, arc.end.y, arc.end.z);
    }

    DEBUG("Target processing complete, recursing");
    // Now that we've done that, we can safely recurse. Count down so that
    // targets.size() is evaluated only once, before we start adding stuff to it.
    for (int i = targets.size()-1; i >= next_target; --i) {
      DEBUG("Processing target %d (nt=%d)", i, next_target);
      FindTargets(targets[i], max_jumps-1);
    }
    DEBUG("FindTargets complete.");
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    // Don't modify hits that aren't part of the initial sweep
    if (damagetype != "None") return damage;
    if (targets.find(target) != targets.size() || !target.bISMONSTER) {
      // Don't zap non-monsters, and don't zap the same thing twice
      return 0;
    }
    targets.push(target);
    return 0;
  }

  // Called every few tics to actually draw the lightning and do the damage.
  void Zap() {
    if (jumps <= 0) { // Nothing left to zap.
      Destroy();
      return;
    }

    DEBUG("Zapping everything with ttl=%d", jumps);
    for (uint i = 0; i < arcs.size(); ++i) {
      let arc = arcs[i];
      arc.UpdatePositions();
      if (arc.ttl != jumps) continue;
      DrawZap(arc.start, arc.end);
      if (arc.to) ApplyDamage(arc.to);
      // TODO: lightning bolt sound effect here
    }
    --jumps;
  }

  // TODO: still not entirely happy about this VFX, it seems to consistently
  // aim low even with FAF_TOP.
  void DrawZap(Vector3 start, Vector3 end) {
    self.warp(self, start.x, start.y, start.z, 0, WARPF_NOCHECKPOSITION|WARPF_ABSOLUTEPOSITION);
    // There's no equivalent to A_Face that takes a position rather than an actor,
    // so instead we spawn in the on-hit vfx and then turn to look at it.
    let beacon = self.Spawn("::ChainLightning::VFX", end);
    let range = self.Distance3D(beacon);
    self.A_Face(beacon, 0, 180, 0, 0, FAF_BOTTOM, 0);
    DEBUG("Draw zap from [%d,%d,%d] to [%d,%d,%d] range=%d",
      start.x, start.y, start.z, end.x, end.y, end.z, range);
    // Skip beam drawing if particle VFX are turned off.
    if (TFLV::Settings.vfx_mode() != TFLV::VFX_FULL) return;
    for (uint i = 0; i < 4; ++i) {
      self.A_CustomRailgun(
        0, 0, "", GetParticleColour(),
        RGF_SILENT|RGF_FULLBRIGHT|RGF_EXPLICITANGLE,
        0, 3, // aim and jaggedness
        "None", // pufftype
        0, 0, //spread
        range, 35*2, // range and duration
        1.0, // particle spacing
        0.2 // drift speed
        );
    }
  }

  void ApplyDamage(Actor victim) {
    let damage = self.damage * (1.0 + 0.01 * (targets.size()-1));
    DEBUG("Chain lightning damaging %s @ (%d,%d,%d) for %d",
      TAG(victim), victim.x, victim.y, victim.z, damage);
    victim.DamageMobj(
      self, self.target, floor(damage), self.DamageType,
      DMG_THRUSTLESS | DMG_NO_ENHANCE);

  }

  string GetParticleColour() {
    static const string colours[] = { "azure", "deepskyblue", "lightskyblue", "ghostwhite" };
    return colours[random(0,3)];
  }
}

class ::ChainLightning::VFX : Actor {
  Default {
    RenderStyle "Add";
    Alpha 0.7;
    Scale 0.2;
    +NOBLOCKMAP +NOGRAVITY;
  }

  override void PostBeginPlay() {
    DEBUG("VFX spawned @ %d,%d,%d", self.pos.x, self.pos.y, self.pos.z);
  }

  States {
    Spawn:
      LLIT ABCDEFGHIJK 3;
      STOP;
  }
}

class ::Thunderbolt::VFX : Actor {
  Default {
    RenderStyle "Add";
    Alpha 1.0;
    Scale 2.0;
    +NOBLOCKMAP +NOGRAVITY;
  }

  override void PostBeginPlay() {
    DEBUG("VFX spawned @ %d,%d,%d", self.pos.x, self.pos.y, self.pos.z);
  }

  States {
    Spawn:
      LTHN ABCD 1;
      LTHN EFGHI 4;
      LTHN JKLM 1;
      STOP;
  }
}

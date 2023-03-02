// The lightning (air) upgrade tree.
//
// APPRENTICE: SHOCKING INSCRIPTION
// Attacks slow enemies. Slow duration scales with level and weapon damage.
//
// UPGRADE: THUNDERBOLT
// Repeated attacks against the same enemy release a wave of energy that stuns
// it and slows enemies near it.
//
// MASTER: CHAIN LIGHTNING
// Enemies killed with lightning stacks on them chain lightning to nearby
// enemies. Total jump count scales with level; damage scales with total number
// of enemies caught in the chain.
//
// MASTER: REVIVIFICATION
// Your most powerful slain enemy rises as a loyal minion.
#namespace TFLV::Upgrade;
#debug off
// Time that reviv minions will hang around once combat is over (seconds).
const ::TTL = 7;

class ::ShockingInscription : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    // Stack 20% of damage * 200ms of stun, softcap at 1s/level
    let zap = ::ShockDot(::Dot.GiveStacks(
      player, target, "::ShockDot", level*damage*0.2, level*5));
    zap.level = self.level;
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damage-per-stack", string.format("%d", 1.0/(0.2*level/5.0)));
    fields.insert("softcap", AsSeconds(level*35));
  }
}

class ::Revivification : ::ElementalUpgrade {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  Actor minion; // Current revivification minion, if any

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::Thunderbolt", "::ChainLightning");
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("damage-bonus", AsPercentIncrease(1.0 + 0.2*level));
    fields.insert("armour-bonus", AsPercentDecrease(0.8 ** level));
    fields.insert("ttl", ::TTL.."s");
    if (minion) {
      fields.insert("minion", string.format("%s [%d/%d]", minion.GetTag(), minion.health, minion.SpawnHealth()));
    } else {
      fields.insert("minion", "-");
    }
  }

  override void OnDeactivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    DisableMinion();
  }

  override void OnActivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    EnableMinion();
  }

  void EnableMinion() {
    if (!minion) return;
    if (!minion.bDORMANT) return;
    DEBUG("EnableMinion(%s)", TAG(minion));
    let buff = ::Revivification::AuxBuff(minion.FindInventory("::Revivification::AuxBuff"));
    if (buff) {
      buff.ActivateOwner();
    } else {
      minion = null;
    }
  }

  void DisableMinion() {
    DEBUG("DisableMinion(%s)", TAG(minion));
    if (!minion) return;
    if (minion.bDORMANT) return;
    let buff = ::Revivification::AuxBuff(minion.FindInventory("::Revivification::AuxBuff"));
    if (buff) {
      buff.DeactivateOwner();
    } else {
      minion = null;
    }
  }

  override void OnDamageReceived(Actor pawn, Actor shot, Actor attacker, int damage) {
    EnableMinion();
  }

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    EnableMinion();
  }

  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    if (!ShouldRevive(target)) return;
    DEBUG("Attempting to raise %s", TAG(target));
    let aux = ::Revivification::Aux(target.Spawn("::Revivification::Aux", target.pos));
    aux.target = player;
    aux.tracer = target;
    aux.upgrade = self;
    aux.level = self.level;
  }

  // Should we even attempt to revive the thing we've just killed? Returning true
  // here doesn't guarantee we do -- we might raise something else in the meantime,
  // or it might be unrevivifiable -- but means we will create the aux object that
  // tries to raise it later. Returning false here skips it entirely.
  bool ShouldRevive(Actor target) {
    // DEBUG("ShouldRevive: %s", TAG(target));
    // Don't revive friendlies. Teamkillers never prosper. :(
    if (target.bFRIENDLY || target.bBOSS || !target.bISMONSTER) return false;
    // Always revive if we don't currently have a minion.
    if (!minion || minion.health <= 0) return true;
    // If we do, only revive if the new one is stronger.
    return RelativePower(minion, target) > 1.0;
  }

  // Return the "relative power level" of the new actor with respect to the old.
  // This is 1.0 if they are equally powerful, 2.0 if new is twice as powerful, etc.
  // At the moment we use a very simple metric of maxhp * speed. This gives us a
  // monster ranking of:
  // zombie < imp < chaingunner < soul < pinkie < revenant < caco = pain elemental
  // < hell knight < mancubus < arachnotron < baron < archvile, which looks reasonable.
  // Note that we use max HP for both; earlier designs used current HP for the old,
  // so that as it "wore out" the chance of replacement increased, but this resulted
  // in outcomes where a single minion could reliably solo entire rooms, because by
  // the time it killed something it had probably taken enough damage to be replaced,
  // and the freshly slain enemy would then get immediately raised.
  static double RelativePower(Actor old, Actor new) {
    double oldp = old.SpawnHealth() * old.speed;
    double newp = new.SpawnHealth() * new.speed;
    // DEBUG("RelativePower: %s (%d) vs %s (%d) -> %f",
    //   TAG(old), oldp, TAG(new), newp, newp/oldp);
    return newp/oldp;
  }
}

class ::ChainLightning : ::DotModifier {
  override ::UpgradeElement Element() { return ::ELEM_LIGHTNING; }
  override string DotType() { return "::ShockDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::ShockDot(dot_item).chain = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::Thunderbolt", "::Revivification");
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
    let zap = ::ShockDot(dot_item);
    zap.thunderbolt = level;
    zap.bolt_cap = max(zap.bolt_cap, zap.level * 5);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasIntermediatePrereq(info, "::ShockingInscription");
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("stun-duration", AsSeconds(GetStunDuration(level)));
    fields.insert("radius", AsMeters(GetRadius(level)));
    fields.insert("cap-multiplier", AsPercent(GetCapMultiplier(level)));
  }

  static uint GetRadius(uint level) {
    return 64 + level*64;
  }

  static uint GetStunDuration(uint level) {
    return 14 + 7*level;
  }

  static float GetCapMultiplier(uint level) {
    return 1.0 + (0.9 ** level);
  }
}

// Lightning "dot". Doesn't actually do damage over time, but has some other effects.
class ::ShockDot : ::Dot {
  uint level; // Shocking Inscription level
  uint chain; // Chain Lightning level
  uint thunderbolt; // Thunderbolt level
  uint bolt_cap; // Cap used for Thunderbolt triggers

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
    DEBUG("GetDamage() stacks=%f level=%d boltcap=%d",
      self.stacks, self.level, self.bolt_cap);
    // Thunderbolt triggers once you exceed the softcap by 2x; levels in thunderbolt
    // reduce this, making it easier to trigger
    if (thunderbolt && bolt_cap && stacks >= bolt_cap * ::Thunderbolt.GetCapMultiplier(thunderbolt)) {
      DEBUG("tbolt: lv=%d stacks=%f cap=%f (actual: %f)",
        thunderbolt, stacks, bolt_cap * ::Thunderbolt.GetCapMultiplier(thunderbolt), bolt_cap);
      Kaboom();
    } else {
      --stacks;
    }
    return 0.0;
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
    let scale = 1.0 + 0.01 * stacks;
    // Apply stun to target.
    owner.tics += ceil(::Thunderbolt.GetStunDuration(thunderbolt) * scale);
    bolt_cap = ceil(bolt_cap * 1.25);
    stacks = stacks/2.0;

    // Cut current stacks in half and apply those to everything in the vicinity.
    Array<Actor> targets;
    TFLV::Util.MonstersInRadius(owner, ceil(::Thunderbolt.GetRadius(thunderbolt) * scale), targets);
    for (uint i = 0; i < targets.size(); ++i) {
      if (targets[i] == owner) continue;

      let zap = ::ShockDot(
        ::Dot.GiveStacks(self.target, targets[i], "::ShockDot", stacks, thunderbolt*5));
      zap.stacks = max(zap.stacks, self.stacks);
      zap.bolt_cap = max(zap.bolt_cap, zap.level * 5);
    }
    owner.Spawn("::Thunderbolt::VFX", owner.pos);
  }

  override void OwnerDied() {
    super.OwnerDied();
    // Trigger chain lightning.
    if (chain > 0) ZapZap();
  }

  override void CopyFrom(::Dot _src) {
    super.CopyFrom(_src);
    let src = ::ShockDot(_src);
    self.chain = max(self.chain, src.chain);
    self.thunderbolt = max(self.thunderbolt, src.thunderbolt);
    self.bolt_cap = max(self.bolt_cap, src.bolt_cap);
  }
}

class ::Revivification::Aux : Actor {
  ::Revivification upgrade;
  uint level;

  Default {
    ReactionTime 175; // 5 seconds
  }

  States {
    CheckRevive:
      TNT1 A 0 CheckRevive();
      TNT1 A 1 A_CountDown();
      LOOP;
  }

  override void PostBeginPlay() {
    self.SetStateLabel("CheckRevive");
  }

  void CheckRevive() {
    // Just in case.
    if (!tracer || !tracer.ResolveState("Raise")) {
      DEBUG("%s: giving up, tracer disappeared", TAG(self));
      Destroy();
      return;
    }

    // This might be temporary because e.g. there's something standing on it.
    if (!tracer.CanRaise()) {
      // DEBUG("Can't raise %s, will retry later.", TAG(tracer));
      if (ReactionTime <= 1) {
        DEBUG("%s: giving up on %s, tried too many times", TAG(self), TAG(tracer));
      }
      return;
    }

    // Final check: we can raise it, but has the player raised something else
    // more powerful in the meantime? This is particularly intended to handle
    // the case where the player fires a rocket into a heterogenous group of
    // enemies -- we want to raise the strongest one available.
    if (upgrade.minion && upgrade.minion.health >= 0
        && upgrade.RelativePower(upgrade.minion, tracer) <= 1.0) {
      DEBUG("%s: giving up on %s, current minion %s is more powerful",
        TAG(self), TAG(tracer), TAG(upgrade.minion));
      Destroy(); return;
    }

    // Attempt the actual resurrection.
    DEBUG("Raising %s by %s; current monster count %d/%d",
      tracer.GetTag(), target.GetTag(), tracer.level.killed_monsters, tracer.level.total_monsters);
    // We need to do this before we start wiggling its flags. If we try setting
    // it friendly before we raise it, it won't stick for some reason and will
    // start attacking us.
    if (!target.RaiseActor(tracer)) {
      DEBUG("RaiseActor for %s failed", TAG(tracer));
      Destroy(); return;
    }

    if (upgrade.minion) {
      DEBUG("Killing minion %s to replace it with %s", TAG(upgrade.minion), TAG(tracer));
      upgrade.minion.A_Die("extreme");
    }
    upgrade.minion = tracer;

    // Clear any dots on it.
    tracer.TakeInventory("::FireDot", 255);
    tracer.TakeInventory("::AcidDot", 255);
    tracer.TakeInventory("::PoisonDot", 255);
    tracer.TakeInventory("::ShockDot", 255);
    // Make it friendly and ethereal.
    tracer.A_SetFriendly(true);
    tracer.SetFriendPlayer(self.target.player);
    tracer.bDONTFOLLOWPLAYERS = false;
    tracer.bALWAYSFAST = true;
    tracer.bSOLID = false;
    tracer.A_SetRenderStyle(1.0, STYLE_SHADED);
    tracer.SetShade("8080FF");

    // Give it the force that applies the buff to revivified minions.
    let buff = ::Revivification::AuxBuff(tracer.GiveInventoryType("::Revivification::AuxBuff"));
    if (buff) {
      buff.level = self.level;
      buff.SetStateLabel("Spawn");
    } else {
      DEBUG("Error raising %s", TAG(tracer));
      tracer.Destroy();
    }
    Destroy();
  }
}

class ::Revivification::AuxBuff : Inventory {
  uint level;
  uint ttl;

  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INVENTORY.IGNORESKILL;
    +INVENTORY.UNTOSSABLE;
    +INVENTORY.UNDROPPABLE;
    +INVENTORY.QUIET;
  }

  States {
    Spawn:
      TNT1 A 0 { ttl = ::TTL; }
    CheckTTL:
      TNT1 A 35 CheckTTL();
      LOOP;
    Idle:
      TNT1 A -1;
      STOP;
    DestroyOwner:
      TNT1 A 5;
      TNT1 A 0 { owner.Destroy(); }
  }

  PlayerPawn Controller() {
    return players[owner.FriendPlayer-1].mo;
  }

  void CheckTTL() {
    --ttl;
    //DEBUG("ttl=%d", ttl);
    if (!ttl) {
      DeactivateOwner();
    }
  }

  void ActivateOwner() {
    DEBUG("raux: activating %s", TAG(owner));
    owner.bINVISIBLE = false;
    owner.bSHOOTABLE = true;
    owner.Warp(Controller());
    owner.Activate(self);
    VFX();
    SetStateLabel("Spawn");
  }

  void DeactivateOwner() {
    DEBUG("raux: deactivating %s", TAG(owner));
    VFX();
    owner.Deactivate(self);
    owner.bINVISIBLE = true;
    owner.bSHOOTABLE = false;
    SetStateLabel("Idle");
  }

  void VFX() {
    let pos = owner.pos;
    pos.z += owner.height/2;
    owner.Spawn("::Revivification::VFX", pos);
  }

  override void OwnerDied() {
    DEBUG("raux: %s died", TAG(owner));
    VFX();
    // Destroying the owner ensures that it can't be re-raised or anything.
    // However, we can't do that right away, because Destroy() nulls out existing
    // refs and then our other OnKill/OnDamage handlers will crash.
    // So instead we schedule it for deletion a few tics from now.
    SetStateLabel("DestroyOwner");
  }

  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    ttl = ::TTL;
    if (source is "PlayerPawn") {
      // Only ever deal or receive 1 damage to players.
      newdamage = min(1, damage);
    } else if (passive) {
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

    DEBUG("FindTargets: %s [ttl=%d] (%d,%d,%d) @ (%d,%d,%d)",
      TAG(victim), max_jumps,
      victim.pos.x, victim.pos.y, victim.pos.z,
      self.pos.x, self.pos.y, self.pos.z);
    uint radius = max(victim.radius, 32) * (3+level);
    uint next_target = targets.size();

    // Collect all the new targets, if any, and record the arcs to them.
    Array<Actor> new_targets;
    TFLV::Util.MonstersInRadius(victim, radius, new_targets);
    for (uint i = 0; i < new_targets.size(); ++i) {
      if (targets.find(new_targets[i]) != targets.size()) continue; // Skip monsters we've already hit
      targets.push(new_targets[i]);
      let arc = new("::ChainLightning::Arc");
      arc.RecordPositions(victim, new_targets[i], max_jumps);
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

class ::Revivification::VFX : Actor {
  Default {
    RenderStyle "Add";
    Alpha 1.0;
    Scale 0.3;
    +NOBLOCKMAP +NOGRAVITY;
  }

  override void PostBeginPlay() {
    DEBUG("VFX spawned @ %d,%d,%d", self.pos.x, self.pos.y, self.pos.z);
  }

  States {
    Spawn:
      LRVV ABCDEFGHIJKLMNOPQRSTUVWXY 1;
      STOP;
  }
}

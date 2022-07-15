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
#debug on

class ::ShockingInscription : ::ElementalUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    // TODO: softcap support
    // Stack 20% of damage * 200ms of stun, hardcap at 1s + 1s/level
    let thedot = ::ShockDot(::Dot.GiveStacks(player, target, "::ShockDot", level*damage*0.2, 5+level*5));
    thedot.cap = 5+level*5;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return ::ElementalUpgrade.CanAcceptElement(info, "Lightning");
  }
}

class ::Revivification : ::DotModifier {
  override string DotType() { return "::ShockDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::ShockDot(dot_item).revive = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasIntermediatePrereq(info, "::ShockingInscription");
  }
}

class ::ChainLightning : ::DotModifier {
  override string DotType() { return "::ShockDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    ::ShockDot(dot_item).chain = level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return HasMasteryPrereq(info, "::Revivification", "::Thunderbolt");
  }
}

class ::Thunderbolt : ::DotModifier {
  override string DotType() { return "::ShockDot"; }

  override void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    let shock = ::ShockDot(dot_item);
    DEBUG("Thunderbolt: %d/%d", shock.stacks, shock.cap);
    if (shock.stacks > shock.cap-1) {
      // Trigger the thunderbolt!
      // Damage is number of stacks × (1% of target's health per level) with diminishing returns
      // TODO: once softcap support is implemented, this should bleed off stacks over the softcap
      // rather than all stacks.
      let aux = ::Thunderbolt::Aux(target.Spawn("::Thunderbolt::Aux", target.pos));
      aux.target = player;
      aux.tracer = target;
      let damage = floor(target.SpawnHealth() * 0.01 * shock.stacks * level);
      DEBUG("Krakoom! You smite the %s for %d damage.", target.GetTag(), damage);
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
    let chance = (1.0 - stacks * 0.2) ** revive;
    if (frandom(0.0, 1.0) < chance) return;
    let aux = ::Revivification::Aux(self.Spawn("::Revivification::Aux", owner.pos));
    aux.target = self.target;
    aux.tracer = self.owner;
    aux.level = self.revive;
  }

  void ZapZap() {
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
    buff.level = self.level;
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
    for (uint i = 0; i < 16; ++i) {
      self.Warp(tracer,
        random(-tracer.radius/2, tracer.radius/2),
        random(-tracer.radius/2, tracer.radius/2),
        0, 0, WARPF_TOFLOOR);
      DEBUG("Thunderbolt @[%d,%d,%d]",
        pos.x, pos.y, pos.z);
      self.A_CustomRailgun(
        0, 0, "", GetParticleColour(),
        RGF_SILENT|RGF_FULLBRIGHT|RGF_EXPLICITANGLE|RGF_CENTERZ,
        0, 10, // aim and jaggedness
        "BulletPuff", // pufftype
        0, -90, //spread
        0, 0, // range and duration
        0.5, // particle spacing
        0.5 // drift speed
        );
    }
  }
}

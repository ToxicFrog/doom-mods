// Elemental synthesis abilities, available only to players who have mastered two
// elements on one weapon.
//
// ELEMENTAL BEAM: hitscan only. Elemental effects on target are copied to all
// enemies in the beam.
// ELEMENTAL BLAST: projectile only. Copies to all enemies near target.
// ELEMENTAL WAVE: melee only. Copies to all enemies near you.
#namespace TFLV::Upgrade;

class ::ElementalSynthesis : ::ElementalUpgrade {
  Array<::UpgradeElement> elements; // Primary and secondary elements
  override ::UpgradePriority Priority() { return ::PRI_NULL; }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return GetElementCount(info.upgrades) >= 2
      && GetElementInProgress(info.upgrades) == ::ELEM_NULL
      && info.upgrades.Level(GetClassName()) == 0;
  }

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    if (elements.size() > 0) return;

    let info = TFLV::PerPlayerStats.GetStatsFor(pawn).GetInfoForCurrentWeapon();
    for (::UpgradeElement elem = ::ELEM_NULL+1; elem < ::ELEM_LAST; ++elem) {
      let levels = CountElementLevels(info.upgrades, elem);
      if (levels == 0) continue;
      DEBUG("ES init: %d", elem);
      elements.push(elem);
    }
  }

  string GetColour(uint i) {
    static const string colours[] = { "black", "orange", "purple", "green", "cyan" };
    return colours[elements[i]];
  }

  void CopyElements(Actor src, Actor dst) {
    static const string dots[] = { "", "::FireDot", "::AcidDot", "::PoisonDot", "::ShockDot" };

    DEBUG("CopyElements: %s <- %s", dst.GetTag(), src.GetTag());
    for (uint i = 0; i < elements.size(); ++i) {
      let dotname = dots[elements[i]];
      DEBUG("Check for %s", dotname);
      let srcdot = ::Dot(src.FindInventory(dotname));
      if (!srcdot) continue;
      DEBUG("  srcdot: %s", srcdot.GetTag());
      let dstdot = ::Dot.GiveStacks(srcdot.target, dst, dotname, 0);
      dstdot.stacks = max(dstdot.stacks, srcdot.stacks);
      DEBUG("  afterwards dst stacks=%f", dstdot.amount);
    }
  }
}

class ::ElementalBeam : ::ElementalSynthesis {
  Actor first_hit;

  override bool CheckPriority(Actor inflictor) {
    if (first_hit && inflictor is "::ElementalBeam::Puff") return true;
    return super.CheckPriority(inflictor);
  }

  // TODO: spawn a separate actor that fires the beam and uses DoSpecialDamage
  // to apply the effect.
  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    super.OnDamageDealt(pawn, shot, target, damage);

    if (shot) {
      DEBUG("OnDamageDealt: %s for %d damage with %s", target.GetTag(), damage, shot.GetTag());
    } else {
      DEBUG("OnDamageDealt: %s for %d damage", target.GetTag(), damage);
    }

    if (shot && shot is "::ElementalBeam::Puff") {
      // Copy elements from original victim
      if (first_hit && target != first_hit) CopyElements(first_hit, target);
      return;
    }

    first_hit = target;
    pawn.A_CustomRailgun(
      1, 0,
      GetColour(0), GetColour(1),
      RGF_SILENT|RGF_FULLBRIGHT,
      0, 0, // spread
      "::ElementalBeam::Puff");
    first_hit = null;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return super.IsSuitableForWeapon(info)
      && info.IsHitscanWeapon()
      && !info.weapon.bMELEEWEAPON;
  }
}

class ::ElementalBeam::Puff : BulletPuff {
  property UpgradePriority: special1;
  Default { ::ElementalBeam::Puff.UpgradePriority ::PRI_NULL; }

  States {
    Spawn:
    Melee:
      TNT1 A 1;
      STOP;
  }
}

class ::ElementalBlast : ::ElementalSynthesis {
  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    super.OnDamageDealt(pawn, shot, target, damage);
    let aoe = ::ElementalSynthesis::AoE(target.Spawn(
      "::ElementalSynthesis::Aoe",
      (target.pos.x, target.pos.y, target.pos.z + target.height/2)));
    aoe.src = target;
    aoe.parent = self;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return super.IsSuitableForWeapon(info)
      && info.IsProjectileWeapon();
  }
}

class ::ElementalWave : ::ElementalSynthesis {
  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    super.OnDamageDealt(pawn, shot, target, damage);
    let aoe = ::ElementalSynthesis::AoE(pawn.Spawn(
      "::ElementalSynthesis::Aoe",
      (pawn.pos.x, pawn.pos.y, pawn.pos.z + pawn.height/2)));
    aoe.src = target;
    aoe.parent = self;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return super.IsSuitableForWeapon(info)
      && info.weapon.bMELEEWEAPON;
  }
}

class ::ElementalSynthesis::AoE : Actor {
  Actor src;
  ::ElementalSynthesis parent;

  property UpgradePriority: special1;
  Default { ::ElementalSynthesis::AoE.UpgradePriority ::PRI_NULL; }

  override void PostBeginPlay() {
    self.SetStateLabel("Spawn");
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    DEBUG("DoSpecialDamage: AoE vs. %s", target.GetTag());
    if (target != src && target.bISMONSTER) {
      parent.CopyElements(src, target);
    }
    return 0;
  }

  void SpawnParticles() {
    let range = src.radius * 5;
    for (uint i = 0; i < 16; ++i) {
      A_SpawnParticle(
        parent.GetColour(0), SPF_FULLBRIGHT|SPF_RELVEL|SPF_RELACCEL,
        35, 10, random(0,360), // lifetime, size, angle
        0, 0, 0, // position
        range/35.0, 0, 0, // v
        0, 0, 0); // a
      A_SpawnParticle(
        parent.GetColour(1), SPF_FULLBRIGHT|SPF_RELVEL|SPF_RELACCEL,
        35, 10, random(0,360), // lifetime, size, angle
        0, 0, 0, // position
        range/35.0, 0, 0, // v
        0, 0, 0); // a
    }
  }

  States {
    Spawn:
      TNT1 A 1 NoDelay SpawnParticles();
      TNT1 A 1 A_Explode(1, src.radius * 5, XF_NOSPLASH, false, src.radius * 5);
      STOP;
  }
}

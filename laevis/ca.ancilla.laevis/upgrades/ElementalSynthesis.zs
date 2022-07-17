// Elemental synthesis abilities, available only to players who have mastered two
// elements on one weapon.
//
// ELEMENTAL BEAM: hitscan only. Elemental effects on target are copied to all
// enemies in the beam.
// ELEMENTAL BLAST: projectile only. Copies to all enemies near target.
// ELEMENTAL WAVE: melee only. Copies to all enemies near you.
#namespace TFLV::Upgrade;
#debug on

class ::ElementalSynthesis : ::ElementalUpgrade {
  Array<::UpgradeElement> elements; // Primary and secondary elements
  override ::UpgradePriority Priority() { return ::PRI_NULL; }

  bool HasTwoMasteries(::UpgradeBag bag) {
    return GetElementCount(bag) >= 2 && GetElementInProgress(bag) == ::ELEM_NULL;
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
      let srcdot = ::Dot(src.FindInventory(dots[i]));
      if (!srcdot) continue;
      DEBUG("  srcdot: %s", srcdot.GetTag());
      let dstdot = ::Dot.GiveStacks(srcdot.target, dst, dots[i], 0);
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

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    super.OnDamageDealt(pawn, shot, target, damage);

    if (shot)
      DEBUG("OnDamageDealt: %s for %d damage with %s", target.GetTag(), damage, shot.GetTag());
    else
      DEBUG("OnDamageDealt: %s for %d damage", target.GetTag(), damage);

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
    return info.IsHitscanWeapon() && !info.weapon.bMELEEWEAPON && HasTwoMasteries(info.upgrades);
  }
}

class ::ElementalBeam::Puff : BulletPuff {
  property UpgradePriority: special1;
  Default {
    ::ElementalBeam::Puff.UpgradePriority ::PRI_NULL;
  }
  States {
    Spawn:
    Melee:
      TNT1 A 1;
      STOP;
  }
}

class ::ElementalBlast : ::ElementalSynthesis {
  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsProjectileWeapon() && HasTwoMasteries(info.upgrades);
  }
}

class ::ElementalWave : ::ElementalSynthesis {
  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.weapon.bMELEEWEAPON && HasTwoMasteries(info.upgrades);
  }
}

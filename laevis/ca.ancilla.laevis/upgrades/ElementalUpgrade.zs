// Stuff for the elemental upgrade trees specifically. Mostly concerned with
// upgrade eligibility checking. All elemental (acid/fire/shock/poison) upgrades
// should inherit from ElementalUpgrade or DotModifier.
// TODO: this is pretty gross. It should be generalized so that elemental upgrades
// can answer questions about themselves.
#namespace TFLV::Upgrade;

enum ::UpgradeElement {
  ::ELEM_NULL,
  ::ELEM_FIRE, ::ELEM_ACID, ::ELEM_POISON, ::ELEM_LIGHTNING,
  ::ELEM_LAST
}

class ::ElementalUpgrade : ::BaseUpgrade {
  override ::UpgradePriority Priority() { return ::PRI_ELEMENTAL; }
  virtual ::UpgradeElement Element() { return ::ELEM_NULL; }

  // Suitable for base-level elemental upgrades, checks if the weapon is capable
  // of accepting that element.
  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    ::UpgradeElement inprogress = GetElementInProgress(info.upgrades);
    return inprogress == Element()
      || info.upgrades.Level(GetClassName()) > 0
      || (inprogress == ::ELEM_NULL && GetElementCount(info.upgrades) < 2);
  }

  bool HasIntermediatePrereq(TFLV::WeaponInfo info, string basic) {
    return info.upgrades.Level(basic) >= 2
      && info.upgrades.Level(basic) > info.upgrades.Level(self.GetClassName());
  }

  bool HasMasteryPrereq(TFLV::WeaponInfo info, string intermediate, string alternate) {
    return info.upgrades.Level(intermediate) >= 2
      && info.upgrades.Level(intermediate) > info.upgrades.Level(self.GetClassName())
      && info.upgrades.Level(alternate) == 0;
  }

  static uint CountElementLevels(::UpgradeBag upgrades, ::UpgradeElement elem) {
    let n = 0;
    for (uint i = 0; i < upgrades.upgrades.size(); ++i) {
      let eu = ::ElementalUpgrade(upgrades.upgrades[i]);
      if (eu && eu.Element() == elem) n += eu.level;
    }
    return n;
  }

  static uint GetElementCount(::UpgradeBag upgrades) {
    uint count = 0;
    for (::UpgradeElement elem = ::ELEM_NULL+1; elem < ::ELEM_LAST; ++elem) {
      if (CountElementLevels(upgrades, elem) > 0) ++count;
    }
    return count;
  }

  // A weapon should only ever have one element in progress, so we just return the
  // first one we find.
  static ::UpgradeElement GetElementInProgress(::UpgradeBag upgrades) {
    if (upgrades.Level("::IncendiaryShots") > 0
        && (upgrades.Level("::Conflagration") + upgrades.Level("::InfernalKiln")) == 0)
      return ::ELEM_FIRE;
    if (upgrades.Level("::PoisonShots") > 0
        && (upgrades.Level("::Putrefaction") + upgrades.Level("::Hallucinogens")) == 0)
      return ::ELEM_POISON;
    if (upgrades.Level("::CorrosiveShots") > 0
        && (upgrades.Level("::Embrittlement") + upgrades.Level("::AcidSpray")) == 0)
      return ::ELEM_ACID;
    if (upgrades.Level("::ShockingInscription") > 0
        && (upgrades.Level("::ChainLightning") + upgrades.Level("::Thunderbolt")) == 0)
      return ::ELEM_LIGHTNING;
    return ::ELEM_NULL;
  }
}

// Convenience base class for elemental upgrades that just wiggle some fields
// in a dot the target already has. Subclasses should implement DotType() and
// ModifyDot() and leave the rest alone.
class ::DotModifier : ::ElementalUpgrade {
  virtual string DotType() { return ""; }

  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    let dot_item = ::Dot(target.FindInventory(DotType()));
    if (!dot_item) return;
    ModifyDot(player, shot, target, damage, dot_item);
  }

  virtual void ModifyDot(Actor player, Actor shot, Actor target, int damage, ::Dot dot_item) {
    return;
  }
}

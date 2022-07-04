// Stuff for the elemental upgrade trees specifically. Mostly concerned with
// upgrade eligibility checking. All elemental (acid/fire/shock/poison) upgrades
// should inherit from ElementalUpgrade or DotModifier.
// TODO: this is pretty gross. It should be generalized so that elemental upgrades
// can answer questions about themselves.
#namespace TFLV::Upgrade;

class ::ElementalUpgrade : ::BaseUpgrade {
  override ::UpgradePriority Priority() { return ::PRI_ELEMENTAL; }

  bool HasIntermediatePrereq(TFLV::WeaponInfo info, string basic) {
    return info.upgrades.Level(basic) >= 2
      && info.upgrades.Level(basic) > info.upgrades.Level(self.GetClassName());
  }

  bool HasMasteryPrereq(TFLV::WeaponInfo info, string intermediate, string alternate) {
    return info.upgrades.Level(intermediate) >= 2
      && info.upgrades.Level(intermediate) > info.upgrades.Level(self.GetClassName())
      && info.upgrades.Level(alternate) == 0;
  }

  static bool CanAcceptElement(TFLV::WeaponInfo info, string element) {
    string inprogress = GetElementInProgress(info.upgrades);
    return inprogress == element
      || (inprogress == "" && GetElementCount(info.upgrades) < 2);
  }

  static uint GetElementCount(::UpgradeBag upgrades) {
    uint count = 0;
    if (upgrades.Level("::IncendiaryShots") > 0) ++count;
    if (upgrades.Level("::PoisonShots") > 0) ++count;
    if (upgrades.Level("::CorrosiveShots") > 0) ++count;
    return count;
  }

  // A weapon should only ever have one element in progress, so we just return the
  // first one we find.
  static string GetElementInProgress(::UpgradeBag upgrades) {
    if (upgrades.Level("::IncendiaryShots") > 0
        && (upgrades.Level("::Conflagration") + upgrades.Level("::InfernalKiln")) == 0)
      return "Fire";
    if (upgrades.Level("::PoisonShots") > 0
        && (upgrades.Level("::Putrefaction") + upgrades.Level("::Hallucinogens")) == 0)
      return "Poison";
    if (upgrades.Level("::CorrosiveShots") > 0
        && (upgrades.Level("::Embrittlement") + upgrades.Level("::ExplosiveReaction")) == 0)
      return "Acid";
    return "";
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

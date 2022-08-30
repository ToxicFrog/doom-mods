// A pseudoitem that, when given to the player, attempts to give them a Legendoom
// upgrade appropriate to the weapon described by 'info'.
// This works by repeatedly spawning the appropriate Legendoom random pickup until
// it generates in a way we can use, then either shoving it into the player directly
// or copying some of the info out of it.
#namespace TFLV;
#debug off

class ::LegendoomEffectGiver : ::UpgradeGiver {
  ::LegendoomWeaponInfo info;
  Weapon wpn;
  string prefix;

  Actor upgrade;
  string newEffect;

  bool BeginLevelUp() {
    DEBUG("BeginLevelUp");
    if (info.effectSlots == 0) {
      DEBUG("weapon can't gain effects");
      // Can't get LD effects.
      return false;
    }

    wpn = info.info.wpn; // Get it from the enclosing WeaponInfo
    prefix = wpn.GetClassName();

    if (info.effects.Size() >= info.effectSlots && !info.canReplaceEffects) {
      // The weapon is already at its limit and effect replacement is disabled for
      // it. Do nothing.
      DEBUG("no room for more effects!");
      return false;
    }

    // If we got this far, the weapon has room for a new effect, or is allowed to
    // discard one of its existing effects to make room.
    // Returning true will trigger the CreateUpgrade/IsCreatedUpgradeGood loop,
    // and then InstallUpgrade() will handle replacing an existing effect if
    // necessary.
    return true;
  }

  void CreateUpgrade() {
    if (upgrade) upgrade.Destroy();
    upgrade = Spawn(prefix.."PickupLegendary", (0,0,0));
    DEBUG("Created tentative upgrade %s", upgrade.GetTag());
  }

  bool IsCreatedUpgradeGood() {
    DEBUG("IsCreatedUpgradeGood?");
    if (!info || !wpn) {
      // Something happened to the player's weapon while we were trying to
      // generate the new effect.
      self.Destroy();
      return false;
    }

    string effect = ::LegendoomUtil.GetActiveWeaponEffect(upgrade, prefix);
    if (::LegendoomUtil.GetWeaponRarity(upgrade, prefix) > info.maxRarity) {
      DEBUG("Upgrade %s is too rare!", effect);
      return false;
    }
    // Upgrade is within the rarity bounds, so make sure it doesn't collide with an
    // existing one.
    if (info.effects.Find(effect) != info.effects.Size()) {
      DEBUG("Upgrade %s is a duplicate of an existing effect!", effect);
      return false;
    }
    DEBUG("Upgrade %s looks good.", effect);
    return true;
  }

  // Try to install the upgrade. If we need the player to make a choice about
  // it, jump to the ChooseDiscard state.
  void InstallUpgrade() {
    DEBUG("InstallUpgrade");
    if (!info || !wpn) {
      // Something happened to the player's weapon while we were trying to
      // generate the new effect.
      upgrade.Destroy();
      return;
    }

    string effect = ::LegendoomUtil.GetActiveWeaponEffect(upgrade, prefix);
    string effectname = ::LegendoomUtil.GetEffectTitle(effect);
    console.printf(
      StringTable.Localize("$TFLV_MSG_LD_EFFECT"),
      wpn.GetTag(), effectname);

    if (info.effects.Size() == 0) {
      // No existing effects, so just pick it up as is.
      info.effects.push(effect);
      info.SelectEffect(0);
      // Set a flag on the upgrade so PerPlayerInfo::HandlePickup() can tell that
      // this is an in-place upgrade and not a new weapon.
      upgrade.FindInventory(prefix.."EffectActive").bNOTELEFRAG = true;
      upgrade.Warp(owner);
      return;
    }


    // Existing effects but not all slots are full. Add the effect name to the
    // list of available effects and discard the upgrade.
    if (info.effects.Size() < info.effectSlots) {
      info.effects.push(effect);
      upgrade.Destroy();
      return;
    }

    // Existing effects and all slots are full. Enter a menu-choose state.
    newEffect = effect;
    SetStateLabel("ChooseEffectToDiscard");
  }

  void DiscardEffect(int index) {
    DEBUG("DiscardEffect %d", index);
    if (index < 0) {
      // Player chose to discard the new effect.
      upgrade.Destroy();
      self.Destroy();
      return;
    }

    // Player chose to discard an existing effect.
    string effect = ::LegendoomUtil.GetActiveWeaponEffect(upgrade, prefix);
    info.effects.Push(effect);
    info.DiscardEffect(index);
    upgrade.Destroy();
    self.Destroy();
  }

  // We use States here and not just a simple method because we need to be able
  // to insert delays to let LD item generation code do its things at various
  // times.
  States {
    ChooseUpgrade:
      TNT1 A 0 A_JumpIf(BeginLevelUp(), "TryCreateUpgrade");
      STOP;
    TryCreateUpgrade:
      TNT1 A 2 CreateUpgrade();
      TNT1 A 0 A_JumpIf(IsCreatedUpgradeGood(), "InstallUpgrade");
      LOOP;
    InstallUpgrade:
      TNT1 A 0 InstallUpgrade();
      STOP;
    ChooseEffectToDiscard:
      TNT1 A 1 AwaitChoice("GunBonsaiNewLDEffectMenu");
      LOOP;
    Chosen:
      TNT1 A 0 DiscardEffect(chosen);
      STOP;
  }
}

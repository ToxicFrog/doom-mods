// A pseudoitem that, when given to the player, attempts to give them a Legendoom
// upgrade appropriate to the weapon described by 'wielded'.
// This works by repeatedly spawning the appropriate Legendoom random pickup until
// it generates in a way we can use, then either shoving it into the player directly
// or copying some of the info out of it.

class TFLV_LegendoomEffectGiver : Inventory {
  TFLV_WeaponInfo wielded;
  string prefix;

  Actor upgrade;
  string newEffect;

  Default {
    +Inventory.IgnoreSkill;
    +Inventory.Untossable;
  }

  override bool HandlePickup(Inventory item) {
    // Does not stack, ever.
    return false;
  }

  bool BeginLevelUp() {
    if (wielded.effectSlots == 0) {
      // Can't get LD effects.
      return false;
    }

    prefix = wielded.weapon.GetClassName();

    if (wielded.effects.Size() >= wielded.effectSlots && !wielded.canReplaceEffects) {
      // The weapon is already at its limit and effect replacement is disabled for
      // it. Do nothing.
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
    //console.printf("Created tentative upgrade %s", upgrade.GetTag());
  }

  bool IsCreatedUpgradeGood() {
    if (!wielded || !wielded.weapon) {
      // Something happened to the player's weapon while we were trying to
      // generate the new effect.
      self.Destroy();
      return false;
    }

    string effect = TFLV_Util.GetActiveWeaponEffect(upgrade, prefix);
    if (TFLV_Util.GetWeaponRarity(upgrade, prefix) > wielded.maxRarity) {
      //console.printf("Upgrade %s is too rare!", effect);
      return false;
    }
    // Upgrade is within the rarity bounds, so make sure it doesn't collide with an
    // existing one.
    if (wielded.effects.Find(effect) != wielded.effects.Size()) {
      //console.printf("Upgrade %s is a duplicate of an existing effect!", effect);
      return false;
    }
    //console.printf("Upgrade %s looks good.", effect);
    return true;
  }

  // Try to install the upgrade. Return true if we did (or can't ever), false if
  // we need to wait and retry later.
  bool InstallUpgrade() {
    if (!wielded || !wielded.weapon) {
      // Something happened to the player's weapon while we were trying to
      // generate the new effect.
      self.Destroy();
      return true;
    }

    string effect = TFLV_Util.GetActiveWeaponEffect(upgrade, prefix);
    string effectname = TFLV_Util.GetEffectTitle(effect);

    if (wielded.effects.Size() == 0) {
      // No existing effects, so just pick it up as is.
      console.printf("Your %s gained the effect [%s]!", wielded.weapon.GetTag(), effectname);
      wielded.effects.push(effect);
      wielded.NextEffect();
      // Set a flag on the upgrade so PerPlayerInfo::HandlePickup() can tell that
      // this is an in-place upgrade and not a new weapon.
      upgrade.FindInventory(prefix.."EffectiveActive").bNOTELEFRAG = true;
      upgrade.Warp(owner);
      return true;
    }

    if (wielded.effects.Size() >= wielded.effectSlots) {
      // All slots are full of existing effects, so ask what to do.
      let stats = TFLV_PerPlayerStats.GetStatsFor(PlayerPawn(owner));
      if (stats.currentEffectGiver) {
        // Some other EffectGiver is currently using the menu infrastructure,
        // so wait a tic and try again.
        return false;
      }

      console.printf("Your %s gained the effect [%s]!", wielded.weapon.GetTag(), effectname);
      stats.currentEffectGiver = self;
      newEffect = effect;
      Menu.SetMenu("LaevisLevelUpScreen");
      self.SetStateLabel("AwaitMenuResponse");
      return true;
    }

    // Existing effects but not all slots are full. We have two options here:
    // - push the new one into the effects list. The player gets the effect
    //   and can switch to it when they please. This does mean we don't get the
    //   effect splash screen the first time they select it unless we replicate
    //   the relevant code from Legendoom.
    // - delete the current one and give them the new one. This gets them the
    //   splash screen immediately, but also means it potentially pops up (and
    //   morphs their weapon) in the middle of combat, getting them killed.
    console.printf("Your %s gained the effect [%s]!", wielded.weapon.GetTag(), effectname);
    wielded.effects.push(effect);
    upgrade.Destroy();
    return true;
  }

  void DiscardEffect(int index) {
    if (index < 0) {
      // Player chose to discard the new effect.
      upgrade.Destroy();
      self.Destroy();
      return;
    }

    // Player chose to discard an existing effect.
    // TODO: if they discard the current effect, it remains active on the weapon
    string effect = TFLV_Util.GetActiveWeaponEffect(upgrade, prefix);
    wielded.effects.Delete(index);
    wielded.effects.Push(effect);
    upgrade.Destroy();
    self.Destroy();
  }

  // We use States here and not just a simple method because we need to be able
  // to insert delays to let LD item generation code do its things at various
  // times.
  States {
    LDLevelUp:
      TNT1 A 0 A_JumpIf(BeginLevelUp(), "TryCreateUpgrade");
      STOP;
    TryCreateUpgrade:
      TNT1 A 2 CreateUpgrade();
      TNT1 A 0 A_JumpIf(IsCreatedUpgradeGood(), "InstallUpgrade");
      LOOP;
    WaitRetryInstallUpgrade:
      TNT1 A 1;
    InstallUpgrade:
      TNT1 A 0 A_JumpIf(!InstallUpgrade(), "WaitRetryInstallUpgrade");
      STOP;
    AwaitMenuResponse:
      TNT1 A 1;
      LOOP;
  }
}

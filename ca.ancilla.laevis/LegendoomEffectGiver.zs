// A pseudoitem that, when given to the player, attempts to give them a Legendoom
// upgrade appropriate to the weapon described by 'wielded'.
// This works by repeatedly spawning the appropriate Legendoom random pickup until
// it generates in a way we can use, then either shoving it into the player directly
// or copying some of the info out of it.

class TFLV_LegendoomEffectGiver : Inventory {
  TFLV_WeaponInfo wielded;
  string prefix;

  Actor upgrade;

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

    if (wielded.effects.Size() >= wielded.effectSlots) {
      if (!wielded.canReplaceEffects) {
        // console.printf("%s has no room for more effects.", wielded.weapon.GetTag());
        return false;
      }
      // Create a new effect, respecting the rarity limits and discarding duplicates,
      // and then offer it to the player; give them a menu that lets them either
      // replace an existing effect, or discard the new effect.
      return true;
    }

    // If we got this far, the weapon has room for a new effect.
    // If it has no existing effects, we 'just' need to create one, respecting
    // the rarity limits on the weapon, and shove it into the player.
    return true;
  }

  void CreateUpgrade() {
    if (upgrade) upgrade.Destroy();
    upgrade = Spawn(prefix.."PickupLegendary", (0,0,0));
    //console.printf("Created tentative upgrade %s", upgrade.GetTag());
  }

  bool IsCreatedUpgradeGood() {
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

  void InstallUpgrade() {
    string effect = TFLV_Util.GetActiveWeaponEffect(upgrade, prefix);
    string effectname = TFLV_Util.GetEffectTitle(effect);
    console.printf("Your %s gained the effect [%s]!", wielded.weapon.GetTag(), effectname);

    if (wielded.effects.Size() == 0) {
      // No existing effects, so just pick it up as is.
      wielded.effects.push(effect);
      wielded.NextEffect();
      // Set a flag on the upgrade so PerPlayerInfo::HandlePickup() can tell that
      // this is an in-place upgrade and not a new weapon.
      upgrade.FindInventory(prefix.."EffectiveActive").bNOTELEFRAG = true;
      upgrade.Warp(owner);
      return;
    }

    if (wielded.effects.Size() >= wielded.effectSlots) {
      // All slots are full of existing effects, so ask what to do.
      // TODO: not implemented yet, so instead just evict the first effect?
      upgrade.Destroy();
      return;
    }

    // Existing effects but not all slots are full. We have two options here:
    // - push the new one into the effects list. The player gets the effect
    //   and can switch to it when they please. This does mean we don't get the
    //   effect splash screen the first time they select it unless we replicate
    //   the relevant code from Legendoom.
    // - delete the current one and give them the new one. This gets them the
    //   splash screen immediately, but also means it potentially pops up (and
    //   morphs their weapon) in the middle of combat, getting them killed.
    wielded.effects.push(effect);
    upgrade.Destroy();
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
    InstallUpgrade:
      TNT1 A 0 InstallUpgrade();
      STOP;
  }
}

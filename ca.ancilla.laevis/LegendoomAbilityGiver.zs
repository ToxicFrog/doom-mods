// A pseudoitem that, when given to the player, attempts to give them a Legendoom
// upgrade appropriate to the weapon described by 'wielded'.
// This works by repeatedly spawning the appropriate Legendoom random pickup until
// it generates in a way we can use, then either shoving it into the player directly
// or copying some of the info out of it.

class TFLV_LegendoomAbilityGiver : Inventory {
  TFLV_WeaponInfo wielded;
  string prefix;

  Actor upgrade;

  Default {
    +Inventory.IgnoreSkill;
    +Inventory.Untossable;
  }

  override bool HandlePickup(Inventory item) {
    // Does not stack, ever.
    console.printf("HandlePickup: %s", item.GetTag());
    return false;
  }

  bool BeginLevelUp() {
    if (wielded.abilitySlots == 0) {
      console.printf("%s can't learn LD abilities.", wielded.weapon.GetTag());
      return false;
    }

    prefix = wielded.weapon.GetClassName();

    if (wielded.abilities.Size() >= wielded.abilitySlots) {
      if (!wielded.canReplaceAbilities) {
        console.printf("%s already has as many abilities as it can hold.", wielded.weapon.GetTag());
        return false;
      }
      // Create a new ability, respecting the rarity limits and discarding duplicates,
      // and then offer it to the player; give them a menu that lets them either
      // replace an existing ability, or discard the new ability.
      return true;
    }

    // If we got this far, the weapon has room for a new ability.
    // If it has no existing abilities, we 'just' need to create one, respecting
    // the rarity limits on the weapon, and shove it into the player.
    return true;
  }

  void CreateUpgrade() {
    if (upgrade) upgrade.Destroy();
    upgrade = Spawn(prefix.."PickupLegendary", (0,0,0));
    console.printf("Created tentative upgrade %s", upgrade.GetTag());
  }

  bool IsCreatedUpgradeGood() {
    string ability = TFLV_Util.GetWeaponEffectName(upgrade, prefix);
    if (TFLV_Util.GetWeaponRarity(upgrade, prefix) > wielded.maxRarity) {
      console.printf("Upgrade %s is too rare!", ability);
      return false;
    }
    // Upgrade is within the rarity bounds, so make sure it doesn't collide with an
    // existing one.
    if (wielded.abilities.Find(ability) != wielded.abilities.Size()) {
      console.printf("Upgrade %s is a duplicate of an existing ability!", ability);
      return false;
    }
    console.printf("Upgrade %s looks good.", ability);
    return true;
  }

  void InstallUpgrade() {
    string ability = TFLV_Util.GetWeaponEffectName(upgrade, prefix);
    string abname = TFLV_Util.GetAbilityTitle(ability);
    if (wielded.abilities.Size() == 0) {
      // No existing abilities, so just pick it up as is.
      console.printf("Your %s gained the ability [%s]!", wielded.weapon.GetTag(), abname);
      wielded.abilities.push(ability);
      wielded.currentAbilityName = abname;
      upgrade.Warp(owner);
      return;
    }

    if (wielded.abilities.Size() >= wielded.abilitySlots) {
      // All slots are full of existing abilities, so ask what to do.
      // TODO: not implemented yet, so instead just evict the first ability?
      console.printf("All ability slots are full, replacement not implemented yet.");
      upgrade.Destroy();
      return;
    }

    // Existing abilities but not all slots are full. We have two options here:
    // - push the new one into the abilities list. The player gets the ability
    //   and can switch to it when they please. This does mean we don't get the
    //   ability splash screen the first time they select it unless we replicate
    //   the relevant code from Legendoom.
    // - delete the current one and give them the new one. This gets them the
    //   splash screen immediately, but also means it potentially pops up (and
    //   morphs their weapon) in the middle of combat, getting them killed.
    console.printf("Your %s gained the ability [%s]!", wielded.weapon.GetTag(), abname);
    wielded.abilities.push(ability);
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

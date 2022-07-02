// A pseudoitem that, when given to the player, gives them an upgrade suitable
// to their currently wielded weapon.
#namespace TFLV;

class ::WeaponUpgradeGiver : ::UpgradeGiver {
  TFLV_WeaponInfo wielded;

  override void CreateUpgradeCandidates() {
    // TODO: properly handle the case where the number of valid upgrades is
    // less than the number we want to display.
    while (candidates.size() < 3) {
      let upgrade = ::Upgrade::Registry.GenerateUpgradeForWeapon(wielded);
      if (!AlreadyHasUpgrade(upgrade)) {
        candidates.push(upgrade);
      } else {
        upgrade.Destroy();
      }
    }
  }

  void InstallUpgrade(int index) {
    if (index < 0) {
      console.printf("Level-up rejected!");
    } else {
      console.printf("Your %s gained a level of %s!",
        wielded.weapon.GetTag(), candidates[index].GetName());
      wielded.upgrades.AddUpgrade(candidates[index]);
    }
    Destroy();
  }

  // We use States here and not just a simple method because we need to be able
  // to insert delays to let LD item generation code do its things at various
  // times.
  States {
    ChooseUpgrade:
      TNT1 A 1 AwaitChoice("LaevisWeaponLevelUpMenu");
      LOOP;
    Chosen:
      TNT1 A 0 InstallUpgrade(chosen);
      STOP;
  }
}

// A pseudoitem that, when given to the player, gives them an upgrade suitable
// to their currently wielded weapon.
#namespace TFLV;

class ::WeaponUpgradeGiver : ::UpgradeGiver {
  TFLV_WeaponInfo wielded;

  override void CreateUpgradeCandidates() {
    candidates.clear();
    ::Upgrade::Registry.GenerateUpgradesForWeapon(wielded, candidates);
  }

  void InstallUpgrade(int index) {
    if (index < 0) {
      wielded.FinishLevelUp(null);
    } else {
      wielded.FinishLevelUp(::Upgrade::BaseUpgrade(new(candidates[index].GetClassName())));
    }
    Destroy();
  }

  // We use States here and not just a simple method because we need to be able
  // to insert delays to let LD item generation code do its things at various
  // times.
  States {
    ChooseUpgrade:
      TNT1 A 1 AwaitChoice("GunBonsaiWeaponLevelUpMenu");
      LOOP;
    Chosen:
      TNT1 A 0 InstallUpgrade(chosen);
      STOP;
  }
}

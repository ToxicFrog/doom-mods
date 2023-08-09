// A pseudoitem that, when given to the player, gives them an upgrade suitable
// to their currently wielded weapon.
#namespace TFLV;

class ::WeaponUpgradeGiver : ::UpgradeGiver {
  TFLV_WeaponInfo wielded;
  uint nrof;

  override void CreateUpgradeCandidates() {
    candidates.clear();
    ::Upgrade::Registry.GetRegistry().GenerateUpgradesForWeapon(wielded, candidates);
  }

  void InstallUpgrade(int index) {
    if (index < 0) {
      wielded.RejectLevelUp();
      if (bonsai_autosave_after_level) { wielded.stats.Autosave(); }
      Destroy(); return;
    } else if (candidates.size() == 0) {
      wielded.FinishLevelUp(null);
    } else {
      wielded.FinishLevelUp(::Upgrade::BaseUpgrade(new(candidates[index].GetClassName())));
    }
    if (--nrof) {
      PostBeginPlay();
    } else {
      if (bonsai_autosave_after_level) { wielded.stats.Autosave(); }
      Destroy();
    }
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

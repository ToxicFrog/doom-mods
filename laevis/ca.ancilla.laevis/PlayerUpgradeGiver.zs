// A pseudoitem that, when given to the player, gives them a suitable weapon-
// independent upgrade.
#namespace TFLV;

class ::PlayerUpgradeGiver : ::UpgradeGiver {
  ::PerPlayerStats stats;

  override void CreateUpgradeCandidates() {
    candidates.clear();
    ::Upgrade::Registry.GenerateUpgradesForPlayer(stats, candidates);
  }

  void InstallUpgrade(int index) {
    if (index < 0) {
      stats.FinishLevelUp(null);
    } else {
      stats.FinishLevelUp(::Upgrade::BaseUpgrade(new(candidates[index].GetClassName())));
    }
    Destroy();
  }

  // We use States here and not just a simple method because we need to be able
  // to insert delays to let LD item generation code do its things at various
  // times.
  States {
    ChooseUpgrade:
      TNT1 A 1 AwaitChoice("GunBonsaiPlayerLevelUpMenu");
      LOOP;
    Chosen:
      TNT1 A 0 InstallUpgrade(chosen);
      STOP;
  }
}

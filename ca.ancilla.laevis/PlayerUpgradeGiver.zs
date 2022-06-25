// A pseudoitem that, when given to the player, gives them a suitable weapon-
// independent upgrade.
#namespace TFLV;

class ::PlayerUpgradeGiver : ::UpgradeGiver {
  ::PerPlayerStats stats;

  // TODO: we might want to force the first upgrade to always be a damage bonus
  // or some other simple, generally useful upgrade.
  override void CreateUpgradeCandidates() {
    while (candidates.size() < 3) {
      let upgrade = ::Upgrade::Registry.GenerateUpgradeForPlayer(stats);
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
      console.printf("You gained a level of %s!", candidates[index].GetName());
      stats.upgrades.AddUpgrade(candidates[index]);
    }
    Destroy();
  }

  // We use States here and not just a simple method because we need to be able
  // to insert delays to let LD item generation code do its things at various
  // times.
  States {
    ChooseUpgrade:
      TNT1 A 1 AwaitChoice("LaevisPlayerLevelUpMenu");
      LOOP;
    Chosen:
      TNT1 A 0 InstallUpgrade(chosen);
      STOP;
  }
}

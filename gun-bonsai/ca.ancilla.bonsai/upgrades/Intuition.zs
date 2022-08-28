#namespace TFLV::Upgrade;
#debug off;

class ::Intuition : ::BaseUpgrade {
  override void OnActivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    super.OnActivate(stats, info);
    stats.owner.level.allmap = true;
    if (self.level >= 2) {
      stats.owner.GiveInventoryType("::Intuition::Power");
    }
  }

  override void OnDeactivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    super.OnDeactivate(stats, info);
    stats.owner.level.allmap = false;
    stats.owner.TakeInventory("::Intuition::Power", 255);
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return stats.upgrades.Level("::Intuition") < 2;
  }
}

class ::Intuition::Power : PowerScanner {
  Default { Powerup.Duration 0x7FFFFFFF; }
}

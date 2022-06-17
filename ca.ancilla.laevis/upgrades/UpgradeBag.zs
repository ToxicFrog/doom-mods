// A collection of BaseUpgrades and some utility functions to manipulate them.
class TFLV_UpgradeBag : Object {
  array<TFLV_BaseUpgrade> upgrades;

  TFLV_BaseUpgrade Add(string classname) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (upgrades[i].GetClassName() == classname) {
        upgrades[i].level++;
        return upgrades[i];
      }
    }
    let upgrade = TFLV_BaseUpgrade(new(classname));
    upgrade.level = 1;
    upgrades.Push(upgrade);
    return upgrade;
  }

  void DumpToConsole(string prefix) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      console.printf("%s%s (%d)", prefix, upgrades[i].GetClassName(), upgrades[i].level);
    }
  }

  ui void DumpToMenu(TFLV_StatusDisplay menu) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      menu.PushInfo(upgrades[i].GetClassName(), string.format("Level %d", upgrades[i].level));
    }
  }

  void OnProjectileCreated(PlayerPawn pawn, Actor shot) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      upgrades[i].OnProjectileCreated(pawn, shot);
    }
  }

  double ModifyDamageDealt(PlayerPawn pawn, Actor shot, Actor target, double damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      damage = upgrades[i].ModifyDamageDealt(pawn, shot, target, damage);
    }
    return damage;
  }

  double ModifyDamageReceived(PlayerPawn pawn, Actor shot, Actor attacker, double damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      damage = upgrades[i].ModifyDamageReceived(pawn, shot, attacker, damage);
    }
    return damage;
  }

  void OnDamageDealt(PlayerPawn pawn, Actor shot, Actor target, int damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      upgrades[i].OnDamageDealt(pawn, shot, target, damage);
    }
  }

  void OnDamageReceived(PlayerPawn pawn, Actor shot, Actor attacker, int damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      upgrades[i].OnDamageReceived(pawn, shot, attacker, damage);
    }
  }
}

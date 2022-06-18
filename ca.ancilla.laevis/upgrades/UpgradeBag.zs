#namespace TFLV::Upgrade;

// A collection of BaseUpgrades and some utility functions to manipulate them.
class ::UpgradeBag : Object play {
  array<::BaseUpgrade> upgrades;

  ::BaseUpgrade Add(string classname) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (upgrades[i].GetClassName() == classname) {
        upgrades[i].level++;
        return upgrades[i];
      }
    }
    let upgrade = ::BaseUpgrade(new(classname));
    upgrade.level = 1;
    upgrades.Push(upgrade);
    return upgrade;
  }

  void DumpToConsole(string prefix) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      console.printf("%s%s (%d): %s", prefix,
          upgrades[i].GetName(), upgrades[i].level, upgrades[i].GetDesc());
    }
  }

  ui void DumpToMenu(TFLV::Menu::StatusDisplay menu) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      menu.PushInfo(
        string.format("%s (%d)", upgrades[i].GetName(), upgrades[i].level),
        upgrades[i].GetDesc());
    }
  }

  void OnProjectileCreated(Actor pawn, Actor shot) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      upgrades[i].OnProjectileCreated(pawn, shot);
    }
  }

  double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      damage = upgrades[i].ModifyDamageDealt(pawn, shot, target, damage);
    }
    return damage;
  }

  double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      damage = upgrades[i].ModifyDamageReceived(pawn, shot, attacker, damage);
    }
    return damage;
  }

  void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      upgrades[i].OnDamageDealt(pawn, shot, target, damage);
    }
  }

  void OnDamageReceived(Actor pawn, Actor shot, Actor attacker, int damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      upgrades[i].OnDamageReceived(pawn, shot, attacker, damage);
    }
  }
}

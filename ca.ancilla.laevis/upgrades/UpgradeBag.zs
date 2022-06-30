#namespace TFLV::Upgrade;

// A collection of BaseUpgrades and some utility functions to manipulate them.
class ::UpgradeBag : Object play {
  array<::BaseUpgrade> upgrades;

  void Tick() {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      upgrades[i].Tick();
    }
  }

  ::BaseUpgrade Add(string classname, uint level=1) {
    return AddUpgrade(::BaseUpgrade(new(classname)), level);
  }

  ::BaseUpgrade AddUpgrade(::BaseUpgrade upgrade, uint level=1) {
    let classname = upgrade.GetClassName();
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (upgrades[i].GetClassName() == classname) {
        upgrades[i].level += level;
        return upgrades[i];
      }
    }
    upgrade.level = level;
    upgrades.Push(upgrade);
    return upgrade;
  }

  uint Level(string cls) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (upgrades[i].GetClassName() == cls) {
        return upgrades[i].level;
      }
    }
    return 0;
  }

  void DumpToConsole(string prefix) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      console.printf("%s%s (%d): %s", prefix,
          upgrades[i].GetName(), upgrades[i].level, upgrades[i].GetDesc());
    }
  }

  ui void DumpToMenu(TFLV::Menu::GenericMenu menu) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      menu.PushKeyValueText(
        string.format("%s (%d)", upgrades[i].GetName(), upgrades[i].level),
        upgrades[i].GetDesc(),
        Font.CR_DARKRED);
    }
  }

  void OnProjectileCreated(Actor pawn, Actor shot) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      upgrades[i].OnProjectileCreated(pawn, shot);
    }
  }

  double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      DEBUG("UpgradeBag.ModifyDamageDealt: %d %s", i, TFLV::Util.SafeCls(upgrades[i]));
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

  void OnKill(Actor pawn, Actor shot, Actor target) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      upgrades[i].OnKill(pawn, shot, target);
    }
  }
}

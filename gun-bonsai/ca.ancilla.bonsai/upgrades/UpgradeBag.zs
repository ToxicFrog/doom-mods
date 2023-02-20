#namespace TFLV::Upgrade;

// A collection of BaseUpgrades and some utility functions to manipulate them.
class ::UpgradeBag : Object play {
  array<::BaseUpgrade> upgrades;

  void Tick(Actor owner) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (upgrades[i].enabled) upgrades[i].Tick(owner);
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
    upgrade.enabled = true;
    upgrades.Push(upgrade);
    return upgrade;
  }

  uint Level(string cls) const {
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

  ui void DumpInteractableToMenu(TFLV::Menu::GenericMenu menu, uint bag_index) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      menu.PushUpgradeToggle(upgrades[i], bag_index, i);
    }
  }

  // Called to activate/deactivate the entire UpgradeBag at once, usually when
  // switching weapons.
  // Not called for disabled upgrades; they should have gotten OnDeactivate when
  // they were originally disabled and should not OnActivate until they are re-
  // enabled.
  void OnActivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (upgrades[i].enabled) upgrades[i].OnActivate(stats, info);
    }
  }

  void OnDeactivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (upgrades[i].enabled) upgrades[i].OnDeactivate(stats, info);
    }
  }

  void OnProjectileCreated(Actor pawn, Actor shot) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (!upgrades[i].enabled || !upgrades[i].CheckPriority(shot)) continue;
      upgrades[i].OnProjectileCreated(pawn, shot);
    }
  }

  double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage, Name attacktype) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      DEBUG("UpgradeBag.ModifyDamageDealt: %d %s", i, upgrades[i].GetClassName());
      if (!upgrades[i].enabled || !upgrades[i].CheckPriority(shot)) continue;
      damage = upgrades[i].ModifyDamageDealt(pawn, shot, target, damage, attacktype);
    }
    return damage;
  }

  double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage, Name attacktype) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (!upgrades[i].enabled) continue;
      // No priority checks -- always triggers, even on self-damage.
      damage = upgrades[i].ModifyDamageReceived(pawn, shot, attacker, damage, attacktype);
    }
    return damage;
  }

  void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      DEBUG("ODD Priority(%s) == %d vs. %d",
        TAG(shot), (shot?shot.weaponspecial:-999), upgrades[i].Priority());
      if (!upgrades[i].enabled || !upgrades[i].CheckPriority(shot)) continue;
      upgrades[i].OnDamageDealt(pawn, shot, target, damage);
    }
  }

  void OnDamageReceived(Actor pawn, Actor shot, Actor attacker, int damage) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (!upgrades[i].enabled) continue;
      // No priority checks -- always triggers, even on self-damage.
      upgrades[i].OnDamageReceived(pawn, shot, attacker, damage);
    }
  }

  void OnKill(PlayerPawn pawn, Actor shot, Actor target) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (!upgrades[i].enabled) continue;
      // No priority checks -- fires unconditionally. This is so that upgrades that
      // have both an ondamage effect and an onkill effect can function, but means
      // that upgrades that want to avoid recursing must check for that themselves.
      upgrades[i].OnKill(pawn, shot, target);
    }
  }

  void OnPickup(PlayerPawn pawn, Inventory item) {
    for (uint i = 0; i < upgrades.Size(); ++i) {
      if (!upgrades[i].enabled) continue;
      upgrades[i].OnPickup(pawn, item);
    }
  }
}

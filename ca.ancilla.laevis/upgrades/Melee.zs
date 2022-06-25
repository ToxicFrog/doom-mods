// Melee-only upgrades.
// These tend to be much more powerful than the non-melee equivalents.
#namespace TFLV::Upgrade;

// Like Resistance, but a much more powerful melee-only version.
// 50% resistance, 75% when upgraded.
class ::Shield : ::BaseUpgrade {
  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    return damage * (0.5 ** self.level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.weapon.bMELEEWEAPON && info.upgrades.Level("::Shield") < 2;
  }
}

class ::DarkHarvest : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    double leech = target.SpawnHealth() * level * 0.05;
    if (leech >= 1) {
      player.GiveInventory("::DarkHarvest::Health", floor(leech));
      player.GiveInventory("::DarkHarvest::Armour", floor(leech));
    }
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.weapon.bMELEEWEAPON;
  }
}

class ::DarkHarvest::Health : Health {
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 999;
  }
}

class ::DarkHarvest::Armour : BasicArmorBonus {
  Default {
    Armor.SaveAmount 1;
    Armor.MaxSaveAmount 999;
  }
}

// Melee-only upgrades.
// These tend to be much more powerful than the non-melee equivalents.
#namespace TFLV::Upgrade;
#debug off

class ::Agonizer : ::BaseUpgrade {
  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    target.GiveInventoryType("::Agonizer::Aux");
    let aux = ::Agonizer::Aux(target.FindInventory("::Agonizer::Aux"));
    if (aux) {
      DEBUG("Adding an Agonizer to %s", target.GetTag());
      aux.amount = 14 * level;
      aux.dtype = shot ? shot.DamageType : Name("AgonizerPain");
    }
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.weapon.bMELEEWEAPON;
  }
}

class ::Agonizer::Aux : Inventory {
  Name dtype;
  override void Tick() {
    DEBUG("Agonizer triggering pain chance! %d", amount);
    owner.TriggerPainChance(dtype, true);
    if (--amount <= 0) Destroy();
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

class ::Swiftness : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    player.GiveInventory("::Swiftness::Aux", level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.weapon.bMELEEWEAPON;
  }
}

class ::Swiftness::Aux : PowerupGiver {
  Default {
    +Inventory.AUTOACTIVATE;
    +Inventory.ADDITIVETIME;
    +Inventory.NOSCREENBLINK;
    Powerup.Type "PowerTimeFreezer";
    Powerup.Duration 70;
    Inventory.Amount 1;
    Inventory.MaxAmount 0;
  }
}

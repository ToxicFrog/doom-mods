// Melee-only upgrades.
// These tend to be much more powerful than the non-melee equivalents.
#namespace TFLV::Upgrade;
#debug off;

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
  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    let amount = target.bBOSS ? level*10 : level;
    // same cap for health and armour; in vanilla this will be 100 + 20 per level.
    // we derive the cap for armour from the cap for health because armour caps
    // aren't intrinsic to the player or even intrinsic to the armour they're
    // wearing, they're intrinsic to the *armour pickup* which vanishes as soon
    // as it grants them AC!
    let cap = player.GetMaxHealth() * (1.0 + 0.2*level);
    let hp = Health(player.Spawn("::DarkHarvest::Health"));
    if (hp) {
      hp.Amount = amount;
      hp.MaxAmount = cap;
      GiveItem(player, hp);
    }

    let ap = BasicArmorBonus(player.Spawn("::DarkHarvest::Armour"));
    if (ap) {
      ap.SaveAmount = amount;
      ap.MaxSaveAmount = cap;
      GiveItem(player, ap);
    }
  }

  void GiveItem(PlayerPawn player, Inventory item) {
    item.ClearCounters();
    if (!item.CallTryPickup(player)) item.Destroy();
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.weapon.bMELEEWEAPON;
  }
}

class ::DarkHarvest::Health : HealthBonus {
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 200;
    Inventory.PickupMessage "";
  }
}

class ::DarkHarvest::Armour : BasicArmorBonus {
  Default {
    Armor.SaveAmount 1;
    Armor.MaxSaveAmount 200;
    Inventory.PickupMessage "";
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
  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
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

// Melee-only upgrades.
// These tend to be much more powerful than the non-melee equivalents.
#namespace TFLV::Upgrade;
#debug off;

class ::DarkHarvest : ::BaseUpgrade {
  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    let amount = target.bBOSS ? level*10 : level;
    // same cap for health and armour; in vanilla this will be 100 + 20 per level.
    // we derive the cap for armour from the cap for health because armour caps
    // aren't intrinsic to the player or even intrinsic to the armour they're
    // wearing, they're intrinsic to the *armour pickup* which vanishes as soon
    // as it grants them AC!
    let cap = player.GetMaxHealth(true) * (1.0 + 0.2*level);
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
    return info.IsMelee() || info.IsWimpy();
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("leech", "+"..level);
    fields.insert("cap", AsPercent(1.0 + 0.2*level));
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

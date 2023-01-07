// Melee-only upgrades.
// These tend to be much more powerful than the non-melee equivalents.
#namespace TFLV::Upgrade;
#debug off;

class ::DarkHarvest : ::BaseUpgrade {
  // Armour cap is based on the best armour you have thus far tried to pick up.
  // Note that it will register the armour even if for some reason the pickup is
  // unsuccessful, and it will also remember it even if your armour is later
  // destroyed or downgraded, so e.g. once you find a blue armour it will use the
  // blue armour cap for the rest of the game.
  // TODO: improve armour cap detection logic.
  uint armour_cap;
  override void OnPickup(PlayerPawn pawn, Inventory item) {
    let armour = BasicArmorPickup(item);
    if (!armour) return;
    armour_cap = max(self.armour_cap, armour.SaveAmount);
  }

  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    let amount = target.bBOSS ? level*10 : level;
    uint hp_cap = player.GetMaxHealth(true) * (1.0 + 0.2*(level-1));
    uint ap_cap = (armour_cap ? armour_cap : hp_cap) * (1.0 + 0.2*(level-1));
    DEBUG("OnKill: cap %d, %d", hp_cap, ap_cap);
    let hp = Health(player.Spawn("::DarkHarvest::Health"));
    if (hp) {
      hp.Amount = amount;
      hp.MaxAmount = hp_cap;
      GiveItem(player, hp);
    }

    let ap = BasicArmorBonus(player.Spawn("::DarkHarvest::Armour"));
    if (ap) {
      ap.SaveAmount = amount;
      ap.MaxSaveAmount = ap_cap;
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

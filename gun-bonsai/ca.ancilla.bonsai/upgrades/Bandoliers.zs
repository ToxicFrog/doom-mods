#namespace TFLV::Upgrade;
#debug off;

class ::Bandoliers : ::BaseUpgrade {
  float AmmoBonus(uint level) {
    return 0.5 * level;
  }

  void UpdateAmmoCaps(Actor player, float bonus) {
    for (Inventory inv = player.inv; inv != null; inv = inv.inv) {
      let ammo = Ammo(inv);
      if (!ammo) continue;
      let has_backpack = ammo.MaxAmount == ammo.BackpackMaxAmount;
      let defaults = GetDefaultByType(ammo.GetClass());
      ammo.BackpackMaxAmount = ceil(defaults.BackpackMaxAmount * bonus);
      ammo.MaxAmount = has_backpack ? ammo.BackpackMaxAmount : ceil(defaults.MaxAmount * bonus);
      DEBUG("%s: %d -> %d (pack=%d)", TAG(ammo), defaults.MaxAmount, ammo.MaxAmount, has_backpack);
    }
  }

  override void OnActivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    super.OnActivate(stats, info);
    UpdateAmmoCaps(stats.owner, 1.0 + AmmoBonus(self.level));
  }

  override void OnDeactivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    super.OnDeactivate(stats, info);
    UpdateAmmoCaps(stats.owner, 1.0);
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("ammo-bonus", AsPercentIncrease(AmmoBonus(level)));
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

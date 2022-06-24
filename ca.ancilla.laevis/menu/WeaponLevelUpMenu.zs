#namespace TFLV::Menu;

class ::WeaponLevelUpMenu : ::GenericMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();

    let pawn = PlayerPawn(players[consoleplayer].mo);
    let stats = TFLV_PerPlayerStats.GetStatsFor(pawn);
    let giver = TFLV::WeaponUpgradeGiver(stats.currentEffectGiver);

    PushText("", Font.CR_GOLD);
    PushText(
      string.format(
        "Your %s has gained a level!",
        giver.wielded.weapon.GetTag()),
      Font.CR_GOLD);
    PushText("Choose an upgrade:", Font.CR_GOLD);

    mDesc.mSelectedItem = -1;
    for (uint i = 0; i < giver.candidates.size(); ++i) {
      PushUpgrade(giver.candidates[i], i);
    }

    PushText("", Font.CR_LIGHTBLUE);
    PushText("Current upgrades:", Font.CR_LIGHTBLUE);
    giver.wielded.upgrades.DumpToMenu(self);
    return;
  }

  void PushUpgrade(TFLV::Upgrade::BaseUpgrade upgrade, int index) {
    PushKeyValueOption(
      upgrade.GetName(), upgrade.GetDesc(),
      "laevis_choose_level_up_option",
      index);
  }
}

#namespace TFLV::Menu;

class ::WeaponLevelUpMenu : ::GenericLevelUpMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Initdynamic(parent, desc);
    TooltipGeometry(0.5, 1.0, 0.75, 1.0, 0.5);
    TooltipAppearance("", "", "tfttbg");

    let stats = TFLV::EventHandler.GetConsolePlayerStats();
    let giver = TFLV::WeaponUpgradeGiver(stats.currentEffectGiver);

    PushText("", Font.CR_GOLD);
    PushText(
      string.format(
        StringTable.Localize("$TFLV_MENU_WEAPON_LEVELUP"),
        giver.wielded.wpn.GetTag()),
      Font.CR_GOLD);

    mDesc.mSelectedItem = -1;
    for (uint i = 0; i < giver.candidates.size(); ++i) {
      PushUpgrade(giver.wielded.upgrades, giver.candidates[i], i);
    }

    PushText("", Font.CR_LIGHTBLUE);
    PushText("$TFLV_MENU_CURRENT_UPGRADES", Font.CR_LIGHTBLUE);
    giver.wielded.upgrades.DumpInteractableToMenu(self, 1);
    return;
  }
}

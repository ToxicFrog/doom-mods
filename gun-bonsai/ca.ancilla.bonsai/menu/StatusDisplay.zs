#namespace TFLV::Menu;

class ::StatusDisplay : ::GenericMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.InitDynamic(parent, desc);
    TooltipGeometry(0.5, 1.0, 0.9, 1.0, 0.5);
    TooltipAppearance("", "", "tfttbg");

    let pps = TFLV::EventHandler.GetConsolePlayerStats();

    TFLV_CurrentStats stats;
    if (!pps.GetCurrentStats(stats)) {
      PushText("", Font.CR_RED);
      PushText("$TFLV_MENU_NO_STATS_FOUND", Font.CR_RED);
      return;
    }

    PushText("", Font.CR_GOLD);
    PushText("$TFLV_MENU_HEADER_PLAYER_STATUS", Font.CR_GOLD);
    PushKeyValueText(
      string.format(StringTable.Localize("$TFLV_MENU_LEVEL"), stats.plvl),
      string.format(StringTable.Localize("$TFLV_MENU_XP"), stats.pxp, stats.pmax));
    stats.pupgrades.DumpInteractableToMenu(self, 0);

    PushText("", Font.CR_GOLD);
    PushText("$TFLV_MENU_HEADER_WEAPON_STATUS", Font.CR_GOLD);
    PushKeyValueText("$TFLV_MENU_TYPE",
      string.format("%s (%s)",
      stats.winfo.wpn.GetTag(), stats.winfo.wpn.GetClassName()));
    PushKeyValueText(
      string.format(StringTable.Localize("$TFLV_MENU_LEVEL"), stats.wlvl),
      string.format(StringTable.Localize("$TFLV_MENU_XP"), stats.wxp, stats.wmax));
    stats.wupgrades.DumpInteractableToMenu(self, 1);

    mDesc.mSelectedItem = -1;
  }
}

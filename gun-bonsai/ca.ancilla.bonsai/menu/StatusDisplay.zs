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
    PushKeyValueText(string.format("Level %d", stats.plvl), string.format("%d/%d XP", stats.pxp, stats.pmax));
    stats.pupgrades.DumpInteractableToMenu(self, 0);

    PushText("", Font.CR_GOLD);
    PushText("$TFLV_MENU_HEADER_WEAPON_STATUS", Font.CR_GOLD);
    PushKeyValueText("Type", string.format("%s (%s)",
        stats.winfo.wpn.GetTag(), stats.winfo.wpn.GetClassName()));
    PushKeyValueText(string.format("Level %d", stats.wlvl),
        string.format("%d/%d XP", stats.wxp, stats.wmax));
    stats.wupgrades.DumpInteractableToMenu(self, 1);

    mDesc.mSelectedItem = -1;
    let ld_info = stats.winfo.ld_info;
    if (ld_info.effects.size() > 0) {
      PushText("", Font.CR_GOLD);
      PushText("$TFLV_MENU_HEADER_WEAPON_LD_EFFECTS", Font.CR_GOLD);
      for (uint i = 0; i < ld_info.effects.size(); ++i) {
        if (ld_info.currentEffect == i) {
          PushEffect(ld_info.effects[i], i, true);
          mDesc.mSelectedItem = mDesc.mItems.Size() - 1;
        } else {
          PushEffect(ld_info.effects[i], i, false);
        }
      }
    }
  }

  void PushEffect(string effect, uint index, bool isDefault) {
    PushKeyValueOption(
      TFLV::LegendoomUtil.GetEffectTitle(effect),
      TFLV::LegendoomUtil.GetEffectDesc(effect),
      "bonsai-select-effect",
      index,
      isDefault ? Font.CR_ORANGE : Font.CR_DARKRED,
      isDefault ? Font.CR_YELLOW : Font.CR_RED);
  }
}

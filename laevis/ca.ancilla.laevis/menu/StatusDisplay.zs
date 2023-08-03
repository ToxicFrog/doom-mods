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
    PushText("$TFLV_MENU_HEADER_WEAPON_STATUS", Font.CR_GOLD);
    PushKeyValueText("$TFLV_MENU_TYPE",
      string.format("%s (%s)",
      stats.winfo.wpn.GetTag(), stats.winfo.wpn.GetClassName()));

    mDesc.mSelectedItem = -1;
    let info = stats.winfo;
    if (info.effects.size() > 0) {
      PushText("", Font.CR_GOLD);
      PushText("$TFLV_MENU_HEADER_WEAPON_LD_EFFECTS", Font.CR_GOLD);
      for (uint i = 0; i < info.effects.size(); ++i) {
        if (info.currentEffect == i) {
          PushEffect(info.effects[i], i, true);
          mDesc.mSelectedItem = mDesc.mItems.Size() - 1;
        } else {
          PushEffect(info.effects[i], i, false);
        }
      }
    }
  }

  void PushEffect(string effect, uint index, bool isDefault) {
    PushKeyValueOption(
      TFLV::LegendoomUtil.GetEffectTitle(effect),
      TFLV::LegendoomUtil.GetEffectDesc(effect),
      "laevis-select-effect",
      index,
      isDefault ? Font.CR_ORANGE : Font.CR_DARKRED,
      isDefault ? Font.CR_YELLOW : Font.CR_RED);
  }
}

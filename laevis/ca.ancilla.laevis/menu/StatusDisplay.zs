#namespace TFLV::Menu;

class ::StatusDisplay : ::GenericMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();

    let pawn = PlayerPawn(players[consoleplayer].mo);
    let pps = TFLV_PerPlayerStats.GetStatsFor(pawn);

    TFLV_CurrentStats stats;
    if (!pps.GetCurrentStats(stats)) {
      PushText("", Font.CR_RED);
      PushText("No stats available for current weapon.", Font.CR_RED);
      PushText("Make sure you have a weapon equipped.", Font.CR_RED);
      PushText("If you do, shoot something with it and try again.", Font.CR_RED);
      return;
    }

    PushText("", Font.CR_GOLD);
    PushText("Player Stats", Font.CR_GOLD);
    PushKeyValueText(string.format("Level %d", stats.plvl), string.format("%d/%d XP", stats.pxp, stats.pmax));
    stats.pupgrades.DumpToMenu(self);

    PushText("", Font.CR_GOLD);
    PushText("Weapon Stats", Font.CR_GOLD);
    PushKeyValueText("Type", string.format("%s (%s)",
        stats.winfo.weapon.GetTag(), stats.winfo.weapon.GetClassName()));
    PushKeyValueText(string.format("Level %d", stats.wlvl),
        string.format("%d/%d XP", stats.wxp, stats.wmax));
    stats.wupgrades.DumpToMenu(self);

    mDesc.mSelectedItem = -1;
    let ld_info = stats.winfo.ld_info;
    if (ld_info.effects.size() > 0) {
      PushText("", Font.CR_GOLD);
      PushText("Weapon Effects", Font.CR_GOLD);
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
      "laevis_select_effect",
      index,
      isDefault ? Font.CR_ORANGE : Font.CR_DARKRED,
      isDefault ? Font.CR_YELLOW : Font.CR_RED);
  }
}

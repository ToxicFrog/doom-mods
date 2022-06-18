#namespace TFLV::Menu;

class ::PlayerLevelUpMenu : ::GenericMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();

    let pawn = PlayerPawn(players[consoleplayer].mo);
    let pps = TFLV_PerPlayerStats.GetStatsFor(pawn);

    PushText("", Font.CR_RED);
    PushText("Menu not implemented yet.", Font.CR_RED);
    mDesc.mSelectedItem = -1;
    return;
  }
}

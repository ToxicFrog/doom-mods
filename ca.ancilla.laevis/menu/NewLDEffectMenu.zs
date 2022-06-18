#namespace TFLV::Menu;

class ::NewLDEffectMenu : ::GenericMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();
    mDesc.mSelectedItem = -1;

    let pawn = PlayerPawn(players[consoleplayer].mo);
    let stats = TFLV_PerPlayerStats.GetStatsFor(pawn);
    let giver = TFLV::LegendoomEffectGiver(stats.currentEffectGiver);
    if (!giver) {
      console.printf("missing/wrong giver in NewLDEffectMenu");
      if (stats.currentEffectGiver) {
        console.printf("Wanted TFLV::LegendoomEffectGiver, got %s", stats.currentEffectGiver.GetClassName());
      }
    }

    // Code to fill in the menu goes here.
    // We need to figure out the list of effects the player already has, and the
    // effect they're trying to gain, and present one menu entry for each.
    PushText("", Font.CR_GOLD);
    PushText(
      string.format(
        "Your %s has unlocked the effect %s",
        giver.wielded.weapon.GetTag(),
        TFLV_Util.GetEffectTitle(giver.newEffect)),
      Font.CR_GOLD);
    PushText("but already has as many effects as it can hold.", Font.CR_GOLD);
    PushText("Select an effect to discard.", Font.CR_GOLD);
    PushText("", Font.CR_GOLD);
    PushText("New Effect:", Font.CR_CYAN);
    PushEffect(giver.newEffect, -1);
    PushText("", Font.CR_LIGHTBLUE);
    PushText("Existing Effects:", Font.CR_LIGHTBLUE);
    for (uint i = 0; i < giver.wielded.effects.size(); ++i) {
      PushEffect(giver.wielded.effects[i], i);
    }
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Back) {
      // Verboten! Can't leave the menu without picking an effect to discard.
      return true;
    }

    return super.MenuEvent(key, fromController);
  }

  void PushEffect(string effect, int index) {
    return PushKeyValueOption(
      TFLV::Util.GetEffectTitle(effect),
      TFLV::Util.GetEffectDesc(effect),
      "laevis_choose_level_up_option",
      index);
  }
}

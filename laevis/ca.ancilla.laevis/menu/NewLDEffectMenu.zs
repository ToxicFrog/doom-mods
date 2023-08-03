#namespace TFLV::Menu;

class ::NewLDEffectMenu : ::GenericMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();
    mDesc.mSelectedItem = -1;

    let stats = TFLV::EventHandler.GetConsolePlayerStats();
    let new_effect = stats.new_effect;
    let info = stats.GetInfoForWeaponMatchingEffect(new_effect);
    if (!new_effect) {
      console.printf("NewLDEffectMenu: no new_effect in playerinfo");
    }

    // Code to fill in the menu goes here.
    // We need to figure out the list of effects the player already has, and the
    // effect they're trying to gain, and present one menu entry for each.
    PushText("", Font.CR_GOLD);
    PushText(string.Format(
        StringTable.Localize("$TFLV_MENU_LD_TOO_MANY_EFFECTS"),
        giver.wpn.GetTag(), TFLV::LegendoomUtil.GetEffectTitle(giver.newEffect)),
      Font.CR_GOLD);
    PushText("", Font.CR_GOLD);
    PushText("$TFLV_MENU_LD_NEW_EFFECT", Font.CR_CYAN);
    PushEffect(new_effect, -1);
    PushText("", Font.CR_LIGHTBLUE);
    PushText("$TFLV_MENU_LD_EXISTING_EFFECTS", Font.CR_LIGHTBLUE);
    for (uint i = 0; i < info.effects.size(); ++i) {
      PushEffect(info.effects[i], i);
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
    PushKeyValueOption(
      TFLV::LegendoomUtil.GetEffectTitle(effect),
      TFLV::LegendoomUtil.GetEffectDesc(effect),
      "bonsai-choose-level-up-option",
      index);
  }
}

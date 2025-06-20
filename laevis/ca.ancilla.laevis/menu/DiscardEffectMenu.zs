#namespace TFLV::Menu;

class ::DiscardEffectMenu : ::GenericMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();
    mDesc.mSelectedItem = -1;

    let stats = TFLV::EventHandler.GetConsolePlayerStats();
    let info = stats.discarding;
    if (!info) {
      console.printf("DiscardEffectMenu: playerinfo.discarding is null!");
    }

    // Two possibilities here: too many active effects or too many passive effects.
    if (info.passives.size() > 1) {
      InitPassives(info);
    } else if (info.effects.size() > info.effectSlots) {
      InitActives(info);
    } else {
      // spurious call
      EventHandler.SendNetworkEvent("laevis-choose-discard", -1);
      return;
    }
  }

  void InitActives(TFLV::WeaponInfo info) {
    PushText("", Font.CR_GOLD);
    PushText(string.Format(
        StringTable.Localize("$TFLV_MENU_LD_TOO_MANY_ACTIVE_EFFECTS"),
        info.wpn.GetTag()),
      Font.CR_GOLD);
    PushText("$TFLV_MENU_LD_CHOOSE_DISCARD", Font.CR_GOLD);
    PushText("$TFLV_MENU_LD_CHOOSE_WARNING", Font.CR_LIGHTBLUE);
    PushText("", Font.CR_LIGHTBLUE);
    for (uint i = 0; i < info.effects.size(); ++i) {
      PushEffect(info.effects[i], i);
    }
  }

  void InitPassives(TFLV::WeaponInfo info) {
    PushText("", Font.CR_GOLD);
    PushText(string.Format(
        StringTable.Localize("$TFLV_MENU_LD_TOO_MANY_PASSIVE_EFFECTS"),
        info.wpn.GetTag()),
      Font.CR_GOLD);
    PushText("$TFLV_MENU_LD_CHOOSE_DISCARD", Font.CR_GOLD);
    PushText("$TFLV_MENU_LD_CHOOSE_WARNING", Font.CR_LIGHTBLUE);
    PushText("", Font.CR_LIGHTBLUE);
    for (uint i = 0; i < info.passives.size(); ++i) {
      PushEffect(info.passives[i], i);
    }
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Back) {
      // Verboten! Can't leave the menu without picking an effect to discard.
      return true;
    }

    return super.MenuEvent(key, fromController);
  }

  void PushEffect(TFLV::LegendoomEffect effect, int index) {
    PushKeyValueOption(
      effect.Title(), effect.Desc(), "laevis-discard-effect", index);
  }
}

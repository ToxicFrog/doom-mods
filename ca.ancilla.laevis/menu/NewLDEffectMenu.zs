#namespace TFLV::Menu;

class ::NewLDEffectMenu : OptionMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();

    let pawn = PlayerPawn(players[consoleplayer].mo);
    let stats = TFLV_PerPlayerStats.GetStatsFor(pawn);
    let giver = stats.currentEffectGiver;

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
    mDesc.mSelectedItem = FirstSelectable();
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Back) {
      // Verboten! Can't leave the menu without picking an effect to discard.
      return true;
    }

    return super.MenuEvent(key, fromController);
  }

  void PushText(string text, uint colour) {
    mDesc.mItems.Push(new("OptionMenuItemStaticText").InitDirect(text, colour));
  }

  void PushEffect(string effect, int index) {
    mDesc.mItems.Push(new("OptionMenuItemEffectSelector").Init(effect, index));
  }

  override int GetIndent() {
    return super.GetIndent() - 200 * CleanXFac_1;
  }
}

class OptionMenuItemEffectSelector : OptionMenuItem {
  // Index of the effect. This is -1 for the new effect, or its index in the
  // 'effects' table for existing effects.
  int index;
  // Effect ID and displayable effect information.
  string effect;
  string effectName;
  string effectDesc;

  OptionMenuItemEffectSelector Init(string effect_, int index_) {
    index = index_;
    effect = effect_;
    effectName = TFLV_Util.GetEffectTitle(effect);
    effectDesc = TFLV_Util.GetEffectDesc(effect);
    super.Init(effectName, "");
    return self;
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key != Menu.MKey_Enter)
      return super.MenuEvent(key, fromController);

    Menu.MenuSound("menu/choose");
    EventHandler.SendNetworkEvent("laevis_choose_effect_discard", index);
    Menu.GetCurrentMenu().Close();
    return true;
  }

  override int Draw(OptionMenuDescriptor d, int y, int indent, bool selected) {
    int color = selected ? Font.CR_RED : Font.CR_DARKRED;
    drawLabel(indent, y, color);
    drawValue(indent, y, color, effectDesc);
    return indent;
  }
}

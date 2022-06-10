class TFLV_LevelUpMenu : OptionMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();

    // Code to fill in the menu goes here.
    // We need to figure out the list of effects the player already has, and the
    // effect they're trying to gain, and present one menu entry for each.
    pushText("Your weapon has gained a new effect,", Font.CR_CYAN);
    pushText("but already has as many effects as it can hold.", Font.CR_CYAN);
    pushText("Select an effect to discard.", Font.CR_CYAN);
    pushText("", Font.CR_CYAN);
    mDesc.mItems.Push(new("OptionMenuItemEffectSelector").Init("LDPistolEffect_Exorcist"));
    mDesc.mItems.Push(new("OptionMenuItemEffectSelector").Init("LDPistolEffect_Pristine"));
    mDesc.mSelectedItem = FirstSelectable();
  }

  override bool MenuEvent(int key, bool fromController) {
    console.printf("MenuEvent! %d", key);
    if (key == Menu.MKey_Back) {
      // Verboten! Can't leave the menu without picking an effect to discard.
      return true;
    }

    return super.MenuEvent(key, fromController);
  }

  void pushText(string text, uint colour) {
    mDesc.mItems.Push(new("OptionMenuItemStaticText").InitDirect(text, colour));
  }

  override int GetIndent() {
    return super.GetIndent() - 200 * CleanXFac_1;
  }
}

class OptionMenuItemEffectSelector : OptionMenuItem {
  string effect;
  string effectName;
  string effectDesc;

  OptionMenuItemEffectSelector Init(string effect_) {
    effect = effect_;
    effectName = TFLV_Util.GetEffectTitle(effect);
    effectDesc = TFLV_Util.GetEffectDesc(effect);
    super.Init(effectName, "");
    return self;
  }

  override bool MenuEvent(int key, bool fromController) {
    console.printf("ItemMenuEvent! %d", key);

    if (key != Menu.MKey_Enter)
      return super.MenuEvent(key, fromController);

    Menu.MenuSound("menu/choose");
    console.printf("Effect chosen: %s", effect);
    // netevent command?
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

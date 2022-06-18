#namespace TFLV::Menu;

class ::WeaponLevelUpMenu : OptionMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();

    let pawn = PlayerPawn(players[consoleplayer].mo);
    let stats = TFLV_PerPlayerStats.GetStatsFor(pawn);
    let giver = TFLV::WeaponUpgradeGiver(stats.currentEffectGiver);

    PushText("", Font.CR_GOLD);
    PushText(
      string.format(
        "Your %s has gained a level!",
        giver.wielded.weapon.GetTag()),
      Font.CR_GOLD);
    PushText("Choose an upgrade:", Font.CR_GOLD);

    mDesc.mSelectedItem = -1;
    for (uint i = 0; i < giver.candidates.size(); ++i) {
      PushUpgrade(giver.candidates[i], i);
    }

    PushText("", Font.CR_LIGHTBLUE);
    PushText("Current upgrades:", Font.CR_LIGHTBLUE);
    // TODO: wiggle menu inheritance tree so that this actually works
    //wielded.upgrades.DumpToMenu(self);
    return;
  }

  void PushText(string text, uint colour) {
    mDesc.mItems.Push(new("OptionMenuItemStaticText").InitDirect(text, colour));
  }

  void PushUpgrade(TFLV::Upgrade::BaseUpgrade upgrade, int index) {
    mDesc.mItems.Push(new("::UpgradeSelector").Init(upgrade, index));
  }

  override int GetIndent() {
    return super.GetIndent() - 200 * CleanXFac_1;
  }
}

class ::UpgradeSelector : OptionMenuItem {
  // Index of the item to be passed to Choose().
  int index;

  // Label and value.
  string label;
  string description;

  ::UpgradeSelector Init(TFLV::Upgrade::BaseUpgrade upgrade, int index_) {
    index = index_;
    label = upgrade.GetName();
    description = upgrade.GetDesc();
    super.Init(label, "");
    return self;
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key != Menu.MKey_Enter)
      return super.MenuEvent(key, fromController);

    Menu.MenuSound("menu/choose");
    EventHandler.SendNetworkEvent("laevis_choose_level_up_option", index);
    Menu.GetCurrentMenu().Close();
    return true;
  }

  override int Draw(OptionMenuDescriptor d, int y, int indent, bool selected) {
    int color = selected ? Font.CR_RED : Font.CR_DARKRED;
    drawLabel(indent, y, color);
    drawValue(indent, y, color, description);
    return indent;
  }
}

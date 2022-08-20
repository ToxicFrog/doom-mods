#namespace TFLV::Menu;

class ::PlayerLevelUpMenu : ::GenericMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();

    let stats = TFLV::EventHandler.GetConsolePlayerStats();
    let giver = TFLV::PlayerUpgradeGiver(stats.currentEffectGiver);

    PushText("", Font.CR_GOLD);
    PushText("You gained a level!", Font.CR_GOLD);
    PushText("Choose an upgrade:", Font.CR_GOLD);

    mDesc.mSelectedItem = -1;
    for (uint i = 0; i < giver.candidates.size(); ++i) {
      PushUpgrade(giver.candidates[i], i);
    }

    PushText("", Font.CR_LIGHTBLUE);
    PushText("Current upgrades:", Font.CR_LIGHTBLUE);
    giver.stats.upgrades.DumpToMenu(self);
    return;
  }

  void PushUpgrade(TFLV::Upgrade::BaseUpgrade upgrade, int index) {
    PushKeyValueOption(
      upgrade.GetName(), upgrade.GetDesc(),
      "bonsai-choose-level-up-option",
      index);
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Back) {
      EventHandler.SendNetworkEvent("bonsai-choose-level-up-option", -1);
    }

    return super.MenuEvent(key, fromController);
  }
}

#namespace TFLV::Menu;

class ::GenericMenu : OptionMenu {
  override int GetIndent() {
    return super.GetIndent() - 200 * CleanXFac_1;
  }

  void PushText(string text, uint colour) {
    Array<string> lines;
    StringTable.Localize(text).Split(lines, "\n");
    for (uint i = 0; i < lines.size(); ++i) {
      mDesc.mItems.Push(new("OptionMenuItemStaticText").InitDirect(lines[i], colour));
    }
  }

  void PushKeyValueText(string key, string value, uint colour = Font.CR_DARKRED) {
    mDesc.mItems.Push(new("::KeyValueText").Init(key, value, colour));
  }

  void PushKeyValueOption(
      string key, string value, string command, int index,
      uint idle = Font.CR_DARKRED, uint hot = Font.CR_RED) {
    mDesc.mItems.Push(new("::KeyValueOption").Init(key, value, command, index, idle, hot));
  }

  void PushUpgradeToggle(TFLV::Upgrade::BaseUpgrade upgrade, uint bag_index, uint index) {
    mDesc.mItems.Push(new("::UpgradeToggle").Init(upgrade, bag_index, index));
  }
}

class ::KeyValueText : OptionMenuItem {
  string key;
  string value;
  uint colour;

  ::KeyValueText Init(string key_, string value_, uint colour_) {
    key = key_;
    value = value_;
    colour = colour_;
    super.Init(key, "");
    return self;
  }

  override bool Selectable() { return false; }

  override int Draw(OptionMenuDescriptor d, int y, int indent, bool selected) {
    drawLabel(indent, y, colour);
    drawValue(indent, y, colour, value);
    return indent;
  }
}

class ::UpgradeToggle : ::KeyValueText {
  TFLV::Upgrade::BaseUpgrade upgrade;
  uint bag_index;
  uint index;

  ::UpgradeToggle Init(TFLV::Upgrade::BaseUpgrade upgrade, uint bag_index, uint index) {
    self.upgrade = upgrade;
    self.bag_index = bag_index;
    self.index = index;
    super.Init(
      string.format("%s (%d)", upgrade.GetName(), upgrade.level),
      upgrade.GetDesc(),
      Font.CR_WHITE);
    return self;
  }

  override bool Selectable() { return true; }

  override int Draw(OptionMenuDescriptor d, int y, int indent, bool selected) {
    if (upgrade.enabled) {
      drawLabel(indent, y, font.CR_DARKRED);
      drawValue(indent, y, selected ? font.CR_RED : font.CR_DARKRED, self.value);
    } else {
      drawLabel(indent, y, font.CR_DARKRED);
      drawValue(indent, y, selected ? font.CR_DARKGRAY : font.CR_BLACK,
        string.format("\c[BLACK][OFF]\c- %s", self.value));
    }
    return indent;
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key != Menu.MKey_Enter)
      return super.MenuEvent(key, fromController);

    Menu.MenuSound("menu/choose");
    EventHandler.SendNetworkEvent("bonsai-toggle-upgrade", bag_index, index);
    return true;
  }
}

class ::KeyValueOption : ::KeyValueText {
  string command;
  int index;
  uint idle_colour;
  uint hot_colour;

  ::KeyValueOption Init(string key, string value, string command_, int index_, uint idle, uint hot) {
    super.Init(key, value, idle);
    command = command_;
    index = index_;
    idle_colour = idle;
    hot_colour = hot;
    return self;
  }

  override bool Selectable() { return true; }

  override int Draw(OptionMenuDescriptor d, int y, int indent, bool selected) {
    colour = selected ? hot_colour : idle_colour;
    return super.Draw(d, y, indent, selected);
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key != Menu.MKey_Enter)
      return super.MenuEvent(key, fromController);

    Menu.MenuSound("menu/choose");
    EventHandler.SendNetworkEvent(command, index);
    Menu.GetCurrentMenu().Close();
    return true;
  }
}

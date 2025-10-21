// Common menu code shared between the level select and inventory menus.

#namespace GZAP;

#include "../archipelago/Location.zsc"
#include "./LevelSelectMenuItems.zsc"

class ::CommonMenu : ::TooltipOptionMenu {
  void PushText(string text, uint colour = Font.CR_WHITE) {
    Array<string> lines;
    StringTable.Localize(text).Split(lines, "\n");
    for (int i = 0; i < lines.size(); ++i) {
      mDesc.mItems.Push(new("OptionMenuItemStaticText").InitDirect(lines[i], colour));
    }
  }

  void PushKeyValueNetevent(
    string key, string value, string command, int index,
    uint idle = Font.CR_DARKRED, uint hot = Font.CR_RED) {
    mDesc.mItems.Push(new("::KeyValueNetevent").Init(key, value, command, index, idle, hot));
  }

  void PushKeyValueText(string key, string value, uint colour = Font.CR_DARKRED) {
    mDesc.mItems.Push(new("::KeyValueText").Init(key, value, colour));
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

class ::KeyValueSelectable : ::KeyValueText {
  uint idle_colour;
  uint hot_colour;

  ::KeyValueSelectable Init(
      string key, string value, uint idle = Font.CR_DARKRED, uint hot = Font.CR_RED) {
    super.Init(key, value, idle);
    idle_colour = idle;
    hot_colour = hot;
    return self;
  }

  override bool Selectable() { return true; }

  virtual int GetColour(bool selected) {
    return selected ? self.hot_colour : self.idle_colour;
  }

  override int Draw(OptionMenuDescriptor d, int y, int indent, bool selected) {
    self.colour = GetColour(selected);
    return super.Draw(d, y, indent, selected);
  }
}

class ::KeyValueNetevent : ::KeyValueSelectable {
  string command;
  int index;

  ::KeyValueNetevent Init(
      string key, string value, string command, int index,
      uint idle = Font.CR_DARKRED, uint hot = Font.CR_RED) {
    super.Init(key, value, idle, hot);
    self.command = command;
    self.index = index;
    return self;
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

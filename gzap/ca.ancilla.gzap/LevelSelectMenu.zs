// Level-select menu for Archipelago.
// TODO: A lot of this is a stripped-down copy of the upgrade-select menu from
// Gun Bonsai, which I should probably factor out into some generic menu utils
// and put in libtooltipmenu.

#namespace GZAP;

#include "./archipelago/Location.zsc"

// Shim between the main menu and the level select menu.
// If activated before game initialization, just forwards to the normal new-game
// menu. Otherwise, opens the AP level select menu.
class ListMenuItemArchipelagoItem : ListMenuItemTextItem {
  override bool Activate() {
    if (level.MapName == "") {
      return super.Activate();
    } else {
      Menu.SetMenu("ArchipelagoLevelSelectMenu");
      return true;
    }
  }
}

class ::LevelSelectMenu : ::TooltipOptionMenu {
  // override int GetIndent() {
  //   return super.GetIndent() - 200 * CleanXFac_1;
  // }

  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.InitDynamic(parent, desc);
    TooltipGeometry(0.0, 0.5, 0.2, 1.0, 0.5);
    TooltipAppearance("", "", "tfttbg");

    PushText("\nLevel Select\n", Font.CR_WHITE);
    PushKeyValueOption("Return to Hub", "", "ap-level-select", HubIndex());
    PushText("\n");

    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      // Sometimes we get MAPINFO entries that don't actually exist.
      if (!info || !LevelInfo.MapExists(info.MapName)) continue;

      let apinfo = ::PlayEventHandler.GetMapInfo(info.MapName);
      // Skip any levels not listed in the data package and initialized with
      // RegisterMap().
      if (!apinfo) continue;

      PushLevelSelector(i, info, apinfo);
    }
  }

  int HubIndex() {
    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      if (info && info.MapName == "GZAPHUB") return i;
    }
    return 0;
  }

  void PushText(string text, uint colour = Font.CR_WHITE) {
    Array<string> lines;
    StringTable.Localize(text).Split(lines, "\n");
    for (int i = 0; i < lines.size(); ++i) {
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

  void PushLevelSelector(int idx, LevelInfo info, ::Region region) {
    mDesc.mItems.Push(new("::LevelSelector").Init(idx, info, region));
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Back) {
      // TODO: What happens if they exit out of the level select?
      // We should probably permit this, *but* if they try to enter normal gameplay
      // in the hub, we kick them back to the menu.
      // Not sure how to do that without an EventHandler that just opens the menu
      // OnTick, which is kind of gross.
    }

    return super.MenuEvent(key, fromController);
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

class ::KeyValueOption : ::KeyValueText {
  string command;
  int index;
  uint idle_colour;
  uint hot_colour;

  ::KeyValueOption Init(
      string key, string value, string command_,
      int index_, uint idle = Font.CR_DARKRED, uint hot = Font.CR_RED) {
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

class ::LevelSelector : ::KeyValueOption {
  LevelInfo info;
  ::Region region;

  ::LevelSelector Init(int idx, LevelInfo info, ::Region region) {
    self.info = info;
    self.region = region;
    super.Init(
      FormatLevelKey(info, region),
      FormatLevelValue(info, region),
      "ap-level-select", idx);
    return self;
  }

  override void Ticker() {
    self.key = FormatLevelKey(info, region);
    self.value = FormatLevelValue(info, region);
  }

  override bool Selectable() {
    return region.access;
  }

  string FormatLevelKey(LevelInfo info, ::Region region) {
    if (!Selectable()) {
      return string.format("\c[BLACK]%s (%s)", info.LookupLevelName(), info.MapName);
    }
    return string.format("%s%s (%s)",
      region.cleared ? "\c[GOLD]" : "",
      info.LookupLevelName(),
      info.MapName);
  }

  string FormatLevelValue(LevelInfo info, ::Region region) {
    if (!Selectable()) {
      return string.format(
        "\c[BLACK][%3d/%-3d checks]  [%d/%d keys]  [%s]  [locked]",
        region.ChecksFound(), region.ChecksTotal(),
        region.KeysFound(), region.KeysTotal(),
        region.automap ? "map" : "   "
      );
    }
    return string.format(
      "%s[%3d/%-3d checks]  %s[%d/%d keys]  %s  %s",
      region.ChecksFound() == region.ChecksTotal() ? "\c[GOLD]" : "\c-",
      region.ChecksFound(), region.ChecksTotal(),
      region.KeysFound() == region.KeysTotal() ? "\c[GOLD]" : "\c-",
      region.KeysFound(), region.KeysTotal(),
      region.automap ? "\c[GREEN][map]" : "\c[BLACK][   ]",
      region.cleared ? "\c[GOLD][done]" : "\c[GREEN][open]"
    );
  }
}
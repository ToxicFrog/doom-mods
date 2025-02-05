// Level-select menu for Archipelago.
// TODO: A lot of this is a stripped-down copy of the upgrade-select menu from
// Gun Bonsai, which I should probably factor out into some generic menu utils
// and put in libtooltipmenu.

#namespace GZAP;

#include "./Keyring.zsc"

// Ok I really need to use TooltipOptionMenu for this instead, ListMenu is a hot mess
class ::LevelSelectMenu : ::TooltipOptionMenu {
  // override int GetIndent() {
  //   return super.GetIndent() - 200 * CleanXFac_1;
  // }

  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.InitDynamic(parent, desc);
    TooltipGeometry(0.5, 1.0, 0.75, 1.0, 0.5);
    TooltipAppearance("", "", "tfttbg");

    PushText("\nLevel Select\n", Font.CR_WHITE);
    PushKeyValueText("map", "clear? checks am keys");

    // TODO: should we use FindLevelByNum() here instead? That's guaranteed to
    // return levels in "proper" order, but if they're discontiguous we have a
    // problem.
    // TODO: Only return levels that are in the data package.
    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      if (!info || !LevelInfo.MapExists(info.MapName)) continue;
      PushLevelSelector(info);
    }
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

  void PushLevelSelector(LevelInfo info) {
    let ring = ::Keyring.Get(consoleplayer).GetRingIfExists(info.MapName);
    PushKeyValueOption(
      FormatLevelKey(info),
      FormatLevelValue(info, ring),
      "ap-level-select",
      info.LevelNum
    );
    // PushTooltip(...level tooltip info goes here...)
  }

  // Display level as:
  // *  N/M  MAP  BkYkRk  BsYsRs  MAP01 | Entryway
  // TODO: is there a way we can scavenge code from ListMenuItemPatchItem to
  // display icons for level clear, have automap, and which keys we have?
  // TODO: we need to know (from the data package?) which keys the level could
  // potentially have, so that we know which ones to display as greyed out
  string FormatLevelKey(LevelInfo info) {
    return string.format("%s (%s)", info.LookupLevelName(), info.MapName);
  }

  string FormatLevelValue(LevelInfo info, ::Subring ring) {
    if (!ring) return "NO KEYRING";
    return string.format(
      "%5s  %3d/%-3d  %3s  %d",
      ring.cleared ? "CLEAR" : "",
      ring.checked.CountUsed(), ::PlayEventHandler.Get().CountChecks(info.MapName),
      ring.automap ? "\c[GREEN]MAP" : "\c[DARKGREY]MAP",
      ring.keys.Size()
    );
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Back) {
      // TODO: What happens if they exit out of the level select?
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

#namespace GZAP;

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

class ::KeyValueNetevent : ::KeyValueText {
  string command;
  int index;
  uint idle_colour;
  uint hot_colour;

  ::KeyValueNetevent Init(
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

class ::LevelSelector : ::KeyValueNetevent {
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
      // TODO: menu updates when the level is cleared, but this gold colour doesn't
      // take effect until the menu is closed and reopened for some reason.
      region.cleared ? "\c[GOLD]" : "",
      info.LookupLevelName(),
      info.MapName);
  }

  string FormatItemCounter(::Region region) {
    let found = region.LocationsChecked();
    let total = region.LocationsTotal();
    return string.format("%s%3d/%-3d",
      found == total ? "\c[GOLD]" : "\c-", found, total);
  }

  // Given a key, produce an icon for it in the level select menu.
  // Use squares for keycards, circles for skulls, and diamonds for everything else.
  // Try to colour it appropriately based on its name, too.
  string FormatKey(string key, bool value) {
    let key = key.MakeLower();
    static const string[] keytypes = { "card", "skull", "" };
    static const string[] keyicons = { "□", "■", "○", "●", "◇", "◆" };
    static const string[] keycolors = { "red", "orange", "yellow", "green", "blue", "purple" };

    string icon; uint i;
    foreach (keytype : keytypes) {
      if (key.IndexOf(keytype) != -1) {
        icon = keyicons[i + (value ? 1 : 0)];
        break;
      }
      i += 2;
    }

    string clr = "white";
    for (i=0; i < keycolors.Size(); ++i) {
      if (key.IndexOf(keycolors[i]) != -1) {
        clr = keycolors[i];
        break;
      }
    }

    string buf = "\c[" .. clr .."]" .. icon;
    return buf.filter();
  }

  string FormatKeyCounter(::Region region, bool color = true) {
    let found = region.KeysFound();
    let total = region.KeysTotal();

    if (total > 7) {
      return string.format("%s%3d/%-3d",
        (found == total && color) ? "\c[GOLD]" : "", found, total);
    }

    let buf = "";
    foreach (k, v : region.keys) {
      buf = buf .. FormatKey(k, v);
    }
    for (int i = region.KeysTotal(); i < 7; ++i) buf = buf.." ";
    return buf;
  }

  string FormatLevelValue(LevelInfo info, ::Region region) {
    if (!Selectable()) {
      return string.format(
        "\c[BLACK]%3d/%-3d  %s  \c[BLACK]%s  %s",
        region.LocationsChecked(), region.LocationsTotal(),
        FormatKeyCounter(region, false),
        region.automap ? " √ " : "   ",
        region.cleared ? "  √  " : "     "
      );
    }
    return string.format(
      "%s  %s  %s  %s",
      FormatItemCounter(region),
      FormatKeyCounter(region),
      region.automap ? "\c[GOLD] √ " : "   ",
      region.cleared ? "\c[GOLD]  √  " : "     "
    );
  }
}

// use □■ for keycards, ●○ for skulls, √ for generic checks, ◆◇ for unknown keys

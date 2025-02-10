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
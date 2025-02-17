#namespace GZAP;

#include "./CommonMenu.zsc"

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
    // I can see that FormatLevelKey is returning the right colour, it's just
    // not updating the display.
    // self.key = FormatLevelKey(info, region);
    if (region.cleared) {
      self.idle_colour = Font.CR_GOLD;
      self.hot_colour = Font.CR_WHITE;
    } else if (region.access) {
      self.idle_colour = Font.CR_DARKRED;
      self.hot_colour = Font.CR_FIRE;
    } else {
      self.idle_colour = Font.CR_BLACK;
      self.hot_colour = Font.CR_BLACK;
    }
    self.value = FormatLevelValue(info, region);
  }

  override bool Selectable() {
    return region.access;
  }

  string FormatLevelKey(LevelInfo info, ::Region region) {
    return string.format("%s (%s)", info.LookupLevelName(), info.MapName);
  }

  string FormatItemCounter(::Region region) {
    let found = region.LocationsChecked();
    let total = region.LocationsTotal();
    return string.format("%s%3d/%-3d",
      found == total ? "\c[GOLD]" : "\c-", found, total);
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
      buf = buf .. ::LevelSelectMenu.FormatKey(k, v);
    }
    for (int i = region.KeysTotal(); i < 7; ++i) buf = buf.." ";
    return buf;
  }

  string FormatLevelValue(LevelInfo info, ::Region region) {
    if (!region.access) {
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

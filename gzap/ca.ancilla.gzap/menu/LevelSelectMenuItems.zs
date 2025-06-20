#namespace GZAP;

#include "./CommonMenu.zsc"

class ::ProgressIndicator : OptionMenuItemStaticText {
  int victory_time;
  ::RandoState apstate;

  override void Ticker() {
    let victory = apstate.win_conditions.Victorious(apstate);
    if (victory) self.mColor = Font.CR_SAPPHIRE;
    self.mLabel = string.format(
      "MAPS: %2d/%-2d   %8s   TIME: %s",
      apstate.LevelsClear(),
      apstate.win_conditions.nrof_maps,
      victory ? "VICTORY!" : "",
      GetTime());
  }

  string GetTime() {
    // MenuTime() keeps ticking even when we aren't in a menu!
    // We might be able to use it as a global timer, but for now, let's just
    // count in-game time.
    float t = level.TotalTime; // + menu.MenuTime();
    if (apstate.win_conditions.Victorious(apstate)) {
      if (!victory_time) victory_time = t;
      t = victory_time;
    }
    float s = t/TICRATE;
    float m = s/60;
    float h = m/60;
    return string.format("%02d:%02d:%02d", h, m % 60, s % 60);
  }
}

class ::LevelSelector : ::KeyValueNetevent {
  LevelInfo info;
  ::Region region;
  ::Tooltip tt;
  uint txn;

  ::LevelSelector Init(int idx, LevelInfo info, ::Region region) {
    self.info = info;
    self.region = region;
    self.txn = 0;
    super.Init(
      FormatLevelKey(info, region),
      FormatLevelValue(info, region),
      "ap-level-select", idx);
    SetColours();
    return self;
  }

  void SetColours() {
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
  }

  override void Ticker() {
    if (txn == region.txn) return;
    SetColours();
    let value = FormatLevelValue(info, region);
    let tt = FormatTooltip();
    self.value = value;
    self.tt.text = self.FormatTooltip();
    self.txn = region.txn;
  }

  override bool Selectable() {
    // return region.access;
    return true;
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter && !region.access) {
      Menu.MenuSound("menu/invalid");
      return true;
    }

    return super.MenuEvent(key, fromController);
  }

  void RequestHint() {
    let hint = self.region.NextHint();
    if (hint != "") {
      Menu.MenuSound("menu/change");
      EventHandler.SendNetworkCommand("ap-hint", NET_STRING, hint);
    }
  }

  string FormatLevelKey(LevelInfo info, ::Region region) {
    return string.format("%s (%s)", info.LookupLevelName(), info.MapName);
  }

  string FormatItemCounter(::Region region) {
    let found = region.LocationsChecked();
    let total = region.LocationsTotal();
    return string.format("%s%3d/%-3d",
      found == total ? "\c[GOLD]" : "\c[GRAY]", found, total);
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
      buf = buf .. FormatKey(v);
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
        FormatLevelClearMarker(region)
      );
    }
    return string.format(
      "%s  %s  %s  %s%s",
      FormatItemCounter(region),
      FormatKeyCounter(region),
      region.automap ? "\c[GOLD] √ " : "   ",
      FormatLevelClearColour(region),
      FormatLevelClearMarker(region)
    );
  }

  string FormatLevelClearMarker(::Region region) {
    if (region.cleared)
      return "  √  ";
    if (::PlayEventHandler.GetState().win_conditions.specific_maps.CheckKey(region.map))
      return "  X  ";
    return "      ";
  }

  string FormatLevelClearColour(::Region region) {
    if (region.cleared)
      return "\c[GOLD]";
    if (::PlayEventHandler.GetState().win_conditions.specific_maps.CheckKey(region.map))
      return "\c[RED]";
    return "";
  }

  string FormatTooltip() {
    return string.format(
      "%s\n%s%s%s%s",
      FormatLevelStatusTT(region),
      FormatAutomapStatusTT(region),
      FormatMissingKeysTT(region),
      FormatMissingChecksTT(region),
      FormatHintReminderTT(region));
  }

  string FormatLevelStatusTT(::Region region) {
    if (!region.access) {
      string buf = StringTable.Localize("$GZAP_MENU_TT_MAP_LOCKED");
      let hint = region.GetHint(region.AccessTokenFQIN());
      if (hint) {
        buf = buf .. string.format("\n\c-ⓘ %s @ %s", hint.player, hint.location);
      }
      return buf;
    } else if (!region.cleared) {
      return StringTable.Localize("$GZAP_MENU_TT_MAP_OPEN");
    } else {
      return StringTable.Localize("$GZAP_MENU_TT_MAP_DONE");
    }
  }

  string FormatAutomapStatusTT(::Region region) {
    if (!region.automap) {
      return StringTable.Localize("$GZAP_MENU_TT_AM_NO");
    } else {
      return StringTable.Localize("$GZAP_MENU_TT_AM_YES");
    }
  }

  string FormatMissingKeysTT(::Region region) {
    string buf = "";
    foreach (k, v : region.keys) {
      if (!v.held) {
        buf = buf .. string.format("\n  %s %s", FormatKey(v), v.typename);
        let hint = region.GetHint(v.FQIN());
        if (hint) {
          buf = buf .. string.format("\n  \c-ⓘ %s @ %s", hint.player, hint.location);
        }
      }
    }
    if (buf != "") {
      return string.format("\n\c-%s\c[DARKGRAY]%s", StringTable.Localize("$GZAP_MENU_TT_KEYS"), buf);
    } else {
      return buf;
    }
  }

  string FormatMissingChecksTT(::Region region) {
    string buf = "";
    foreach (loc : region.locations) {
      if (loc.checked || loc.IsUnreachable()) continue;

      string colour;
      if (loc.track == AP_UNREACHABLE) {
        colour = "BLACK";
      } else if (loc.track == AP_REACHABLE_OOL) {
        colour = "DARKGRAY";
      } else if (loc.track == AP_REACHABLE_IL) {
        colour = "ICE";
      }
      buf = buf .. string.format("\n  \c[%s]%s", colour, loc.name);

      let peek = region.GetPeek(loc.name);
      if (peek) {
        buf = buf .. string.format("\n  \c-ⓘ %s for %s", peek.item, peek.player);
      }
    }
    if (buf != "") {
      return string.format("\n\c-%s%s", StringTable.Localize("$GZAP_MENU_TT_CHECKS"), buf);
    } else {
      return buf;
    }
  }

  // Given a key, produce an icon for it in the level select menu.
  // Use squares for keycards, circles for skulls, and diamonds for everything else.
  // Try to colour it appropriately based on its name, too.
  string FormatKey(::RandoKey keyinfo) {
    let key = keyinfo.typename.MakeLower();
    static const string[] keytypes = { "card", "skull", "" };
    static const string[] keyicons = { "□", "■", "○", "●", "◇", "◆" };

    string icon; uint i;
    foreach (keytype : keytypes) {
      if (key.IndexOf(keytype) != -1) {
        icon = keyicons[i + (keyinfo.held ? 1 : 0)];
        break;
      }
      i += 2;
    }

    string buf = "\c[" .. ::Util.GetKeyColour(key, "white") .."]" .. icon;
    return buf.filter();
  }

  string FormatHintReminderTT(::Region region) {
    let hint = region.NextHint();
    if (hint == "") {
      return "";
    }
    return string.format("\n\c-%s\c[DARKGRAY]\n  %s", StringTable.Localize("$GZAP_MENU_TT_HINT"), hint);
  }
}

// use □■ for keycards, ●○ for skulls, √ for generic checks, ◆◇ for unknown keys

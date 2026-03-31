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

class ::WeaponSlotInfo {
  int slot;
  int total;
  int found;
  Array<string> weapon_types;
  Map<string, bool> weapons_held;
}

class ::WeaponGrantInfo {
  Array<::WeaponSlotInfo> slot_info;
  string scope;

  string MakeWeaponList(string head_format, string rest_format) {
    let buf = "";
    int last_key = -1;

    for (int slot = 1; slot <= 10; ++slot) {
      let key = slot%10;
      let info = self.slot_info[key];
      if (info.total == 0) continue;

      foreach (weapon : info.weapon_types) {
        Class<Weapon> cls = weapon;
        let held = info.weapons_held.CheckKey(weapon);
        let tag = ::RC.Get().GetTag(GetDefaultByType(cls));
        if (last_key != key) {
          buf.AppendFormat(head_format, held ? "FIRE" : "DARKGRAY", key, tag);
          last_key = key;
        } else {
          buf.AppendFormat(rest_format, held ? "FIRE" : "DARKGRAY", tag);
        }
      }
    }

    return buf;
  }

  string ShortWeaponList() {
    return MakeWeaponList("\c[%s]%d", "\c[%s]+");
  }

  string LongWeaponList() {
    return MakeWeaponList("\n\c[%s]  [%d] %s", "\n\c[%s]   +  %s");
    let buf = "";
    int last_key = -1;
    for (int slot = 1; slot <= 10; ++slot) {
      let key = slot%10;
      let info = self.slot_info[key];
      foreach (weapon : info.weapon_types) {
        Class<Weapon> cls = weapon;
        let held = info.weapons_held.CheckKey(cls.GetClassName());
        if (last_key != key) {
          buf.AppendFormat("\n\c[%s]  [%d] %s", held ? "FIRE" : "DARKGRAY", key, GetDefaultByType(cls).GetTag());
          last_key = key;
        } else {
          buf.AppendFormat("\n\c[%s]   +  %s", held ? "FIRE" : "DARKGRAY", GetDefaultByType(cls).GetTag());
        }
      }
    }
    return buf;
  }

  void UpdateWeaponInfo(::RandoState apstate) {
    self.slot_info.Clear();
    let slots = players[0].weapons;

    for (int slot = 0; slot < 10; ++slot) {
      ::WeaponSlotInfo info = new("::WeaponSlotInfo");
      info.slot = slot;
      info.total = info.found = 0;

      for (int n = 0; n < slots.SlotSize(slot); ++n) {
        let cls = slots.GetWeapon(slot, n);
        let count = apstate.CountItem("::WeaponGrant_"..cls.GetClassName()..self.scope);
        if (count == -1) continue; // Weapon not known to AP
        info.total++;
        info.weapon_types.Push(cls.GetClassName());
        if (count > 0) {
          info.weapons_held.Insert(cls.GetClassName(), true);
          info.found++;
        }
      }
      self.slot_info.Push(info);
    }
  }
}

class ::WeaponIndicator : ::KeyValueText {
  ::Tooltip tt;
  ::RandoState apstate;
  ::WeaponGrantInfo weapon_info;
  uint txn;

  ::WeaponIndicator Init(::RandoState apstate) {
    self.apstate = apstate;
    self.txn = 0;
    self.weapon_info = new("::WeaponGrantInfo");
    weapon_info.UpdateWeaponInfo(apstate);
    super.Init("\c[CYAN]Weapons", "", Font.CR_CYAN);
    return self;
  }

  override void Ticker() {
    if (txn == self.apstate.txn) return;
    self.weapon_info.UpdateWeaponInfo(self.apstate);
    self.value = self.weapon_info.ShortWeaponList();
    self.tt.text = TooltipHeader() .. self.weapon_info.LongWeaponList() .. TooltipFooter();
    self.txn = self.apstate.txn;
  }

  override bool Selectable() { return true; }

  string TooltipHeader() {
    return "\c-"..StringTable.Localize("$GZAP_MENU_TT_WEAPONLIST_PROLOGUE");
  }

  string TooltipFooter() {
    if (self.apstate.wcaps.use_per_map_caps) {
      return "\n\c-"..StringTable.Localize("$GZAP_MENU_TT_WEAPONLIST_EPILOGUE_PERMAP");
    } else {
      return "\n\c-"..StringTable.Localize("$GZAP_MENU_TT_WEAPONLIST_EPILOGUE_PERMAP");
    }
  }
}

class ::LevelSelector : ::KeyValueNetevent {
  LevelInfo info;
  ::RandoState apstate;
  ::Region region;
  ::WeaponGrantInfo weapon_info;
  ::Tooltip tt;
  uint txn;

  ::LevelSelector Init(int idx, LevelInfo info, ::RandoState apstate, ::Region region) {
    self.info = info;
    self.apstate = apstate;
    self.region = region;
    self.weapon_info = new("::WeaponGrantInfo");
    self.weapon_info.scope = "_"..region.map;
    self.txn = 0;
    self.weapon_info.UpdateWeaponInfo(apstate);
    super.Init(
      FormatLevelKey(info, region),
      FormatLevelValue(info, region),
      "ap-level-select", idx);
    SetColours();
    return self;
  }

  void SetColours() {
    if (region.IsCleared()) {
      self.idle_colour = Font.CR_GOLD;
      self.hot_colour = Font.CR_WHITE;
    } else if (region.CanAccess()) {
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
    self.weapon_info.UpdateWeaponInfo(apstate);
    self.value = FormatLevelValue(info, region);
    self.tt.text = self.FormatTooltip();
    self.txn = region.txn;
  }

  override bool Selectable() {
    return true;
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter && !region.CanAccess()) {
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

  void ClearSavedPosition() {
    if (self.region.player_position == (0,0,0)) {
      Menu.MenuSound("menu/invalid");
    } else {
      Menu.MenuSound("menu/change");
      EventHandler.SendNetworkCommand("ap-clear-position", NET_STRING, self.region.map);
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

  string FormatWeaponInfo() {
    if (!self.apstate.IsPerMapWeapons()) return "";
    return "  " .. self.weapon_info.ShortWeaponList();
  }

  string FormatLevelValue(LevelInfo info, ::Region region) {
    if (!region.CanAccess()) {
      return string.format(
        "\c[BLACK]%3d/%-3d  %s%s  \c[BLACK]%s  %s",
        region.LocationsChecked(), region.LocationsTotal(),
        FormatKeyCounter(region, false),
        FormatWeaponInfo(),
        region.HasAutomap() ? " √ " : "   ",
        FormatLevelClearMarker(region)
      );
    }
    return string.format(
      "%s  %s%s  %s  %s%s",
      FormatItemCounter(region),
      FormatKeyCounter(region),
      FormatWeaponInfo(),
      region.HasAutomap() ? "\c[GOLD] √ " : "   ",
      FormatLevelClearColour(region),
      FormatLevelClearMarker(region)
    );
  }

  string FormatLevelClearMarker(::Region region) {
    if (region.IsCleared())
      return "  √  ";
    if (::RandoState.Get().win_conditions.specific_maps.CheckKey(region.map))
      return "  X  ";
    return "      ";
  }

  string FormatLevelClearColour(::Region region) {
    if (region.IsCleared())
      return "\c[GOLD]";
    if (::RandoState.Get().win_conditions.specific_maps.CheckKey(region.map))
      return "\c[RED]";
    return "";
  }

  string FormatTooltip() {
    // The trailing space is intentional so that we never set an empty tooltip,
    // as doing that causes libTTM to delete the tooltip outright and then we
    // can't get it back if we want to set it to something nonempty.
    return string.format(
      "%s%s%s%s%s ",
      FormatLevelStatusTT(region),
      FormatSavedPositionTT(region),
      FormatHintReminderTT(region),
      FormatMissingKeysTT(region),
      FormatMissingChecksTT(region));
  }

  string FormatLevelStatusTT(::Region region) {
    if (!region.CanAccess()) {
      string buf = StringTable.Localize("$GZAP_MENU_TT_MAP_LOCKED") .. "\n";
      let hint = region.GetHint(region.AccessFlagFQIN());
      if (hint) {
        buf = buf .. string.format("\c-%s\n", ::Util.FormatHint(hint.player, hint.location));
      }
      return buf;
    } else if (region.IsCleared()) {
      return StringTable.Localize("$GZAP_MENU_TT_MAP_DONE") .. "\n";
    } else {
      return "";
    }
  }

  string FormatSavedPositionTT(::Region region) {
    if (region.player_position != (0,0,0)) {
      return StringTable.Localize("$GZAP_MENU_TT_SAVED_POSITION") .. "\n";
    } else {
      return "";
    }
  }

  string FormatHintReminderTT(::Region region) {
    let hint = region.NextHint();
    if (hint == "") {
      return "";
    }
    return string.format("\c-%s\c[DARKGRAY]\n  %s\n", StringTable.Localize("$GZAP_MENU_TT_HINT"), hint);
  }

  string FormatMissingKeysTT(::Region region) {
    string buf = "";
    foreach (k, v : region.keys) {
      if (!v.held) {
        buf = buf .. string.format("  %s %s\n", FormatKey(v), v.tag);
        let hint = region.GetHint(v.FQIN());
        if (hint) {
          buf = buf .. string.format("  %s\n", ::Util.FormatHint(hint.player, hint.location));
        }
      }
    }
    if (buf != "") {
      return string.format("\c-%s\c[DARKGRAY]\n%s", StringTable.Localize("$GZAP_MENU_TT_KEYS"), buf);
    } else {
      return buf;
    }
  }

  string FormatMissingChecksTT(::Region region) {
    string buf = "";
    foreach (loc : region.locations) {
      if (loc.IsChecked() || loc.IsUnreachable()) continue;

      string colour;
      if (loc.track == AP_UNREACHABLE) {
        colour = "BLACK";
      } else if (loc.track == AP_REACHABLE_OOL) {
        colour = "FIRE";
      } else if (loc.track == AP_REACHABLE_IL) {
        colour = "ICE";
      }
      buf = buf .. string.format("\n  \c[%s]%s", colour, loc.name);

      if (loc.peek) {
        buf = buf .. string.format("\n  %s", ::Util.FormatPeek(loc.peek.player, loc.peek.item, loc.flags));
      }
    }
    if (buf != "") {
      return string.format("\c-%s%s", StringTable.Localize("$GZAP_MENU_TT_CHECKS"), buf);
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
}

// use □■ for keycards, ●○ for skulls, √ for generic checks, ◆◇ for unknown keys

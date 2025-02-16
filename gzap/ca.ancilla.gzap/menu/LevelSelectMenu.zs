// Level-select menu for Archipelago.
// TODO: A lot of this is a stripped-down copy of the upgrade-select menu from
// Gun Bonsai, which I should probably factor out into some generic menu utils
// and put in libtooltipmenu.
// TODO: if this menu is activated without a data package loaded, it should
// instead open a menu with "scan" and "refine" options for WAD importation.

#namespace GZAP;

#include "../archipelago/Location.zsc"
#include "./LevelSelectMenuItems.zsc"
#include "./CommonMenu.zsc"

// Shim between the main menu and the level select menu.
// If activated before game initialization, just forwards to the normal new-game
// menu. Otherwise, opens the AP level select menu.
// TODO: if we don't have a datapack, this should instead open a scan menu, with
// options to scan the wad, play through vanilla to refine the process, or mark
// certain levels as excluded from the final pack.
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

class ::LevelSelectMenu : ::CommonMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.InitDynamic(parent, desc);
    TooltipGeometry(0.0, 0.5, 0.2, 1.0, 0.5);
    TooltipAppearance("", "", "tfttbg");

    PushText(" ");
    PushText("$GZAP_MENU_LEVEL_SELECT_TITLE", Font.CR_WHITE);
    PushText(" ");

    PushKeyValueText(
      "$GZAP_MENU_HEADER_LEVEL",
      string.format("%7s  %7s  %3s  %5s",
          StringTable.Localize("$GZAP_MENU_HEADER_ITEMS"),
          StringTable.Localize("$GZAP_MENU_HEADER_KEYS"),
          StringTable.Localize("$GZAP_MENU_HEADER_AM"),
          StringTable.Localize("$GZAP_MENU_HEADER_STATUS")));

    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      // Sometimes we get MAPINFO entries that don't actually exist.
      if (!info || !LevelInfo.MapExists(info.MapName)) continue;

      let region = ::PlayEventHandler.GetState().GetRegion(info.MapName);
      // Skip any levels not listed in the data package and initialized with
      // RegisterMap().
      if (!region) continue;

      PushLevelSelector(i, info, region);
      PushLevelSelectorTooltip(region);
    }

    PushText(" ");
    PushKeyValueNetevent("$GZAP_MENU_LEVEL_SELECT_RETURN", "", "ap-level-select", HubIndex());
  }

  int HubIndex() {
    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      if (info && info.MapName == "GZAPHUB") return i;
    }
    return 0;
  }

  void PushLevelSelector(int idx, LevelInfo info, ::Region region) {
    mDesc.mItems.Push(new("::LevelSelector").Init(idx, info, region));
  }

  void PushLevelSelectorTooltip(::Region region) {
    PushTooltip(string.format(
      "%s\n%s%s%s",
      FormatLevelStatusTT(region),
      FormatAutomapStatusTT(region),
      FormatMissingKeysTT(region),
      FormatMissingChecksTT(region)));
  }

  string FormatLevelStatusTT(::Region region) {
    if (!region.access) {
      return StringTable.Localize("$GZAP_MENU_TT_MAP_LOCKED");
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
      if (!v) {
        buf = buf .. string.format("\n  %s %s", FormatKey(k, v), k);
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
      if (!loc.checked) {
        // TODO: this is a gross hack to strip the redundant "MAPNN - " prefix
        // from the check name.
        string shortname = loc.name;
        shortname.replace(region.map .. " - ", "");
        buf = buf .. string.format("\n  %s", shortname);
      }
    }
    if (buf != "") {
      return string.format("\n\c-%s\c[DARKGRAY]%s", StringTable.Localize("$GZAP_MENU_TT_CHECKS"), buf);
    } else {
      return buf;
    }
  }

  // Given a key, produce an icon for it in the level select menu.
  // Use squares for keycards, circles for skulls, and diamonds for everything else.
  // Try to colour it appropriately based on its name, too.
  static string FormatKey(string key, bool value) {
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
}

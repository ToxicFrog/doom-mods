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
    if (::PlayEventHandler.GetState().Victorious()) {
      PushText("$GZAP_MENU_VICTORIOUS", Font.CR_SAPPHIRE);
    }
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
    let item = new("::LevelSelector").Init(idx, info, region);
    mDesc.mItems.Push(item);
    item.tt = PushTooltip(item.FormatTooltip());
  }
}

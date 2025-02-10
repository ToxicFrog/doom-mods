// Level-select menu for Archipelago.
// TODO: A lot of this is a stripped-down copy of the upgrade-select menu from
// Gun Bonsai, which I should probably factor out into some generic menu utils
// and put in libtooltipmenu.
// TODO: if this menu is activated without a data package loaded, it should
// instead open a menu with "scan" and "refine" options for WAD importation.

#namespace GZAP;

#include "../archipelago/Location.zsc"
#include "./LevelSelectMenuItems.zsc"

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

class ::LevelSelectMenu : ::TooltipOptionMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.InitDynamic(parent, desc);
    TooltipGeometry(0.0, 0.5, 0.2, 1.0, 0.5);
    TooltipAppearance("", "", "tfttbg");

    PushText(" ");
    PushText("$GZAP_MENU_LEVEL_SELECT_TITLE", Font.CR_WHITE);
    PushText(" ");


    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      // Sometimes we get MAPINFO entries that don't actually exist.
      if (!info || !LevelInfo.MapExists(info.MapName)) continue;

      let region = ::PlayEventHandler.GetRegion(info.MapName);
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

  void PushLevelSelector(int idx, LevelInfo info, ::Region region) {
    mDesc.mItems.Push(new("::LevelSelector").Init(idx, info, region));
  }
}

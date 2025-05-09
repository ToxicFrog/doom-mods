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

class ::LevelSelectMenu : ::CommonMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.InitDynamic(parent, desc);
    TooltipGeometry(0.0, 0.5, 0.25, 1.0, 0.5);
    TooltipAppearance("", "", "tfttbg");

    if (!::PlayEventHandler.GetState()) {
      console.printf("%s", StringTable.Localize("$GZAP_MENU_ERROR_NOT_IN_GAME"));
      return;
    }

    PushText(" ");
    PushText("$GZAP_MENU_LEVEL_SELECT_TITLE", Font.CR_WHITE);
    let progress_indicator = new("::ProgressIndicator");
    progress_indicator.apstate = ::PlayEventHandler.GetState();
    mDesc.mItems.Push(progress_indicator.InitDirect("", Font.CR_CYAN));
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

    // Does the hub belong to the special Archipelago persistence cluster?
    if (LevelInfo.FindLevelInfo("GZAPHUB").cluster == 38281) {
      PushKeyValueNetevent("$GZAP_MENU_LEVEL_SELECT_RESET", "", "ap-level-select", ResetIndex());
      PushTooltip("$GZAP_MENU_TT_RESET");
    }

    PushKeyValueNetevent("$GZAP_MENU_LEVEL_SELECT_RETURN", "", "ap-level-select", HubIndex());
  }

  int HubIndex() {
    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      if (info && info.MapName == "GZAPHUB") return i;
    }
    return 0;
  }

  int ResetIndex() {
    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      if (info && info.MapName == "GZAPRST") return i;
    }
    return 0;
  }

  void PushLevelSelector(int idx, LevelInfo info, ::Region region) {
    let item = new("::LevelSelector").Init(idx, info, region);
    mDesc.mItems.Push(item);
    item.tt = PushTooltip(item.FormatTooltip());
  }

  override void Ticker() {
    let state = ::PlayEventHandler.GetState();
    if (!state) {
      Close();
      return;
    }

    super.Ticker();
    if (!state.ShouldWarn()) return;

    EventHandler.SendNetworkEvent("ap-did-warning");
    DisplayWarning(::PlayEventHandler.GetState());
  }

  void DisplayWarning(::RandoState state) {
    Menu.StartMessage(
      string.format(
        StringTable.Localize("$GZAP_MENU_WARNING"),
        GetMapWarning(state),
        GetFilterWarning(state)),
      1);
  }

  string GetMapWarning(::RandoState state) {
    if (state.checksum_errors == 0) return "";
    return string.format(
      StringTable.Localize("$GZAP_MENU_WARNING_MAPS"),
      state.checksum_errors,
      state.regions.CountUsed());
  }

  string GetFilterWarning(::RandoState state) {
    let ap_filter_name = ::Util.GetFilterName(state.filter);
    let game_filter_name = ::Util.GetFilterName(::Util.GetCurrentFilter());
    if (ap_filter_name == game_filter_name) return "";
    return string.format(
      StringTable.Localize("$GZAP_MENU_WARNING_SPAWNS"),
      ap_filter_name, game_filter_name);
  }
}

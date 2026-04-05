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

    let apstate = ::RandoState.Get();
    if (!apstate) {
      console.printf("%s", StringTable.Localize("$GZAP_MENU_ERROR_NOT_IN_GAME"));
      return;
    }

    PushText(" ");
    PushText("$GZAP_MENU_LEVEL_SELECT_TITLE", Font.CR_WHITE);
    let progress_indicator = new("::ProgressIndicator");
    progress_indicator.apstate = apstate;
    mDesc.mItems.Push(progress_indicator.InitDirect("", Font.CR_CYAN));

    let slot_info = ::WeaponSlotInfo.Create(apstate);
    let weapon_indicator = new("::WeaponIndicator");
    mDesc.mItems.Push(weapon_indicator.Init(::RandoState.Get(), slot_info));
    weapon_indicator.tt = PushTooltip("[placeholder]");
    PushText(" ");

    bool pmw = apstate.IsPerMapWeapons();

    PushKeyValueText(
      "$GZAP_MENU_HEADER_LEVEL",
      string.format("%7s  %7s  %s%3s  %5s",
          StringTable.Localize("$GZAP_MENU_HEADER_ITEMS"),
          StringTable.Localize("$GZAP_MENU_HEADER_KEYS"),
          pmw ? StringTable.Localize("$GZAP_MENU_HEADER_WEAPONS") : "",
          StringTable.Localize("$GZAP_MENU_HEADER_AM"),
          StringTable.Localize("$GZAP_MENU_HEADER_STATUS")));

    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      // Sometimes we get MAPINFO entries that don't actually exist.
      if (!info || !LevelInfo.MapExists(info.MapName)) continue;

      let region = apstate.GetRegion(info.MapName);
      // Skip any levels not listed in the data package and initialized with
      // RegisterMap().
      if (!region) continue;

      PushLevelSelector(i, info, apstate, slot_info, region);
    }

    PushText(" ");

    // Does the hub belong to the special Archipelago persistence cluster?
    if (LevelInfo.FindLevelInfo("GZAPHUB").cluster == 38281) {
      PushKeyValueNetevent("$GZAP_MENU_LEVEL_SELECT_RESET", "", "ap-level-select", ResetIndex());
      PushTooltip("$GZAP_MENU_TT_RESET");
    }

    PushKeyValueNetevent("$GZAP_MENU_LEVEL_SELECT_RETURN", "", "ap-level-select", ::Util.HubIndex());
  }

  int ResetIndex() {
    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      if (info && info.MapName == "GZAPRST") return i;
    }
    return 0;
  }

  void PushLevelSelector(int idx, LevelInfo info, ::RandoState apstate, ::WeaponSlotInfo slot_info, ::Region region) {
    let item = new("::LevelSelector").Init(idx, info, apstate, slot_info, region);
    mDesc.mItems.Push(item);
    item.tt = PushTooltip(item.FormatTooltip());
  }

  override void Ticker() {
    let state = ::RandoState.Get();
    if (!state) {
      Close();
      return;
    }

    super.Ticker();
    if (!state.ShouldWarn()) return;

    EventHandler.SendNetworkEvent("ap-did-warning");
    DisplayWarning(::RandoState.Get());
  }

	override bool OnUIEvent(UIEvent evt) {
    // Key inputs other than directionals and ok/cancel/clear need to be handled
    // by the menu, not the menu item.
    // 0x48 == 'H'
    if (evt.type == UIEvent.TYPE_CHAR && evt.KeyChar == 0x48) {
      let selected = ::LevelSelector(mDesc.mItems[mDesc.mSelectedItem]);
      if (selected) {
        selected.RequestHint();
      }
      return true;

    // 0x43 == 'C'
    } else if (evt.type == UIEvent.TYPE_CHAR && evt.KeyChar == 0x43) {
      let selected = ::LevelSelector(mDesc.mItems[mDesc.mSelectedItem]);
      if (selected) {
        selected.ClearSavedPosition();
      }
      return true;
    }

    return super.OnUIEvent(evt);
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
    let ap_filter_name = ::Util.GetFilterName(state.filter_index);
    let game_filter_name = ::Util.GetFilterName(::Util.GetSpawnFilterIndex());
    if (ap_filter_name == game_filter_name) return "";
    return string.format(
      StringTable.Localize("$GZAP_MENU_WARNING_SPAWNS"),
      state.filter_index, ap_filter_name,
      ::Util.GetSpawnFilterIndex(), game_filter_name);
  }
}

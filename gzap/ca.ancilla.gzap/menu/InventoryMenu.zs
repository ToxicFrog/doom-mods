// Inventory select menu. Shows all the items players have received from the
// randomizer and lets them summon them.

#namespace GZAP;

#include "../archipelago/RandoState.zsc"
#include "./CommonMenu.zsc"

// TODO: this doesn't auto-update as the player receives new items.
// Kind of tricky to do well since it might add entirely new entries to the menu,
// rather than just editing existing ones.
class ::InventoryMenu : ::CommonMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.InitDynamic(parent, desc);
    TooltipGeometry(0.0, 0.5, 0.2, 1.0, 0.5);
    TooltipAppearance("", "", "tfttbg");

    if (!::PlayEventHandler.GetState()) {
      console.printf("%s", StringTable.Localize("$GZAP_MENU_ERROR_NOT_IN_GAME"));
      return;
    }

    PushText(" ");
    PushText("$GZAP_MENU_INVENTORY_TITLE", Font.CR_WHITE);
    PushText(" ");

    let state = ::PlayEventHandler.GetState();
    for (int n = 0; n < state.items.Size(); ++n) {
      let item = state.items[n];
      if (item.GetLimit() == 0) continue;
      let menu_item = new("::InventoryItem").Init(item);
      mDesc.mItems.Push(menu_item);
      menu_item.tt = PushTooltip(menu_item.FormatTooltip());
    }

    InitKeyDisplay();
    InitRegionDisplay();
    mDesc.mSelectedItem = -1;
  }

  override void Ticker() {
    let state = ::PlayEventHandler.GetState();
    if (!state) {
      Close();
      return;
    }

    super.Ticker();
  }

  override bool OnUIEvent(UIEvent evt) {
    // Key inputs other than directionals and ok/cancel/clear need to be handled
    // by the menu, not the menu item.
    // 0x48 == 'H'
    if (evt.type == UIEvent.TYPE_CHAR && evt.KeyChar == 0x48) {
      let selected = ::KeyToggle(mDesc.mItems[mDesc.mSelectedItem]);
      if (selected) {
        selected.RequestHint();
      }
      return true;
    }

    return super.OnUIEvent(evt);
  }

  void InitKeyDisplay() {
    let region = ::PlayEventHandler.GetState().GetCurrentRegion();
    if (!region) return;
    if (region.keys.CountUsed() == 0) return;

    PushText(" ");
    PushText("$GZAP_MENU_HEADER_KEYS", Font.CR_WHITE);
    PushText(" ");

    foreach (_, key : region.keys) {
      mDesc.mItems.Push(new("::KeyToggle").Init(region, key));
    }
  }

  void InitRegionDisplay() {
    // Do not allow the player to directly wiggle this when not in pretuning mode.
    if (!::PlayEventHandler.Get().IsPretuning()) return;

    let this_region = ::PlayEventHandler.GetState().GetCurrentRegion();
    if (!this_region) return;
    if (!this_region.hub) return; // Only meaningful in a hubcluster

    Array<::Region> regions;
    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      // Sometimes we get MAPINFO entries that don't actually exist.
      if (!info || !LevelInfo.MapExists(info.MapName)) continue;

      let region = ::PlayEventHandler.GetState().GetRegion(info.MapName);
      if (!region) continue;
      if (region.hub != this_region.hub) continue;

      regions.push(region);
    }

    if (regions.Size() <= 1) return;

    PushText(" ");
    PushText("Pretuning region list control");
    PushText(" ");

    foreach (region : regions) {
      mDesc.mItems.Push(new("::RegionToggle").Init(region));
    }
  }
}

class ::InventoryItem : ::KeyValueSelectable {
  ::RandoItem item;
  ::Tooltip tt;

  ::InventoryItem Init(::RandoItem item) {
    self.item = item;
    super.Init(item.tag, FormatValue());
    return self;
  }

  override void Ticker() {
    self.value = FormatValue();
    self.tt.text = FormatTooltip();
    super.Ticker();
  }

  override int GetColour(bool selected) {
    if (!self.Selectable()) return font.CR_BLACK;
    return super.GetColour(selected);
  }

  string FormatValue() {
    if (item.grabbed > 0) {
      return string.format("%3d -> %d", item.Remaining() - item.grabbed, item.grabbed);
    } else {
      return string.format("%3d", item.Remaining());
    }
  }

  string FormatTooltip() {
    return string.format(
      StringTable.Localize("$GZAP_MENU_INVENTORY_ITEM_TT"),
      item.tag, item.typename, item.category, item.Remaining(), item.total);
  }

  override bool Selectable() { return item.Remaining() > 0; }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter) {
      EventHandler.SendNetworkCommand("ap-inv-grab-commit");
      Menu.MenuSound("menu/choose");
      Menu.GetCurrentMenu().Close();
      return true;
    } else if (key == Menu.MKey_Left) {
      EventHandler.SendNetworkCommand("ap-inv-grab-less", NET_STRING, item.typename);
      Menu.MenuSound("menu/change");
      return true;
    } else if (key == Menu.MKey_Right) {
      EventHandler.SendNetworkCommand("ap-inv-grab-more", NET_STRING, item.typename);
      Menu.MenuSound("menu/change");
      return true;
    } else if (key == Menu.MKey_Back) {
      EventHandler.SendNetworkCommand("ap-inv-grab-cancel");
      return super.MenuEvent(key, fromController);
    }

    return super.MenuEvent(key, fromController);
  }
}

class ::KeyToggle : ::KeyValueSelectable {
  ::Region region;
  ::RandoKey key_info;

  ::KeyToggle Init(::Region region, ::RandoKey key_info) {
    self.region = region;
    self.key_info = key_info;
    super.Init(FormatKeyName(), FormatKeyStatus());
    return self;
  }

  override void Ticker() {
    self.key = FormatKeyName();
    self.value = FormatKeyStatus();
    super.Ticker();
  }

  void RequestHint() {
    if (key_info.held) return;
    Menu.MenuSound("menu/change");
    EventHandler.SendNetworkCommand("ap-hint", NET_STRING, key_info.FQIN());
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter) {
      EventHandler.SendNetworkCommand("ap-toggle-key", NET_STRING, key_info.typename);
      Menu.MenuSound("menu/change");
      return true;
    }

    return super.MenuEvent(key, fromController);
  }

  string FormatKeyName() {
    if (key_info.held) {
      return "\c[" .. ::Util.GetKeyColour(key_info.typename, "gray") .."]" .. key_info.tag;
    } else {
      return "\c[BLACK]"..key_info.tag.."\c-";
    }
  }

  string FormatKeyStatus() {
    if (!key_info.held) {
      let hint = region.GetHint(key_info.FQIN());
      if (hint) {
        return string.format("\c[GRAY]ⓘ %s @ %s", hint.player, hint.location);
      } else {
        return StringTable.Localize("$GZAP_MENU_KEY_MISSING");
      }
    } else if (key_info.enabled) {
      return StringTable.Localize("$GZAP_MENU_KEY_ON");
    } else {
      return StringTable.Localize("$GZAP_MENU_KEY_OFF");
    }
  }
}

class ::RegionToggle : ::KeyValueSelectable {
  ::Region region;
  LevelInfo info;

  ::RegionToggle Init(::Region region) {
    self.region = region;
    self.info = LevelInfo.FindLevelInfo(region.map);
    super.Init(FormatRegionName(), FormatRegionStatus());
    return self;
  }

  override void Ticker() {
    self.value = FormatRegionStatus();
    super.Ticker();
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter) {
      EventHandler.SendNetworkCommand("ap-toggle-visited", NET_STRING, region.map);
      Menu.MenuSound("menu/change");
      return true;
    }

    return super.MenuEvent(key, fromController);
  }

  string FormatRegionName() {
    return string.format("%s (%s)", info.LookupLevelName(), region.map);
  }

  string FormatRegionStatus() {
    if (!region.visited) {
      return "\c[GRAY][UNVISITED]\c-";
    } else {
      return "\c[GREEN][VISITED]\c-";
    }
  }
}


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
      if (item.vended < item.total) {
        // TODO: implement a new subtype for inventory menu items that permits
        // asking to vend items without closing the menu.
        PushKeyValueNetevent(item.tag, string.format("%d", item.Remaining()), "ap-use-item", n);
        PushTooltip(string.format("Name: %s\nType: %s\nCategory: %s\nHeld/Found: %d/%d",
          item.tag, item.typename, item.category, item.Remaining(), item.total));
      }
    }

    if (::PlayEventHandler.Get().IsPretuning() || ap_scan_keys_always) {
      InitKeyDisplay();
    }

    if (mDesc.mSelectedItem >= mDesc.mItems.Size()) {
      mDesc.mSelectedItem = -1;
    }
  }

  override void Ticker() {
    let state = ::PlayEventHandler.GetState();
    if (!state) {
      Close();
      return;
    }

    super.Ticker();
  }

  // TODO: we need to scan for new keys before this opens, which probably means
  // when the player picks up the key, immediately.
  void InitKeyDisplay() {
    let region = ::PlayEventHandler.GetState().GetCurrentRegion();
    if (!region) return;
    if (region.keys.CountUsed() == 0) return;

    PushText(" ");
    PushText("$GZAP_MENU_HEADER_KEYS", Font.CR_WHITE);
    PushText(" ");

    foreach (_, key : region.keys) {
      mDesc.mItems.Push(new("::KeyToggle").Init(key));
    }
  }
}

class ::KeyToggle : ::KeyValueNetevent {
  ::RandoKey key_info;

  ::KeyToggle Init(::RandoKey key_info) {
    self.key_info = key_info;
    super.Init(
      FormatKeyName(),
      FormatKeyStatus(),
      "", 0);
    return self;
  }

  override void Ticker() {
    self.key = FormatKeyName();
    self.value = FormatKeyStatus();
    super.Ticker();
  }

  override bool Selectable() {
    return key_info.held;
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
      return "\c[" .. ::Util.GetKeyColour(key_info.typename, "gray") .."]" .. key_info.typename;
    } else {
      return "\c[BLACK]"..key_info.typename.."\c-";
    }
  }

  string FormatKeyStatus() {
    if (!key_info.held) {
      return string.format("\c[BLACK]%s\c-", StringTable.Localize("$GZAP_MENU_KEY_MISSING"));
    } else if (key_info.enabled) {
      return string.format("\c[GREEN]%s\c-", StringTable.Localize("$GZAP_MENU_KEY_ON"));
    } else {
      return string.format("\c[BLACK]%s\c-", StringTable.Localize("$GZAP_MENU_KEY_OFF"));
    }
  }
}

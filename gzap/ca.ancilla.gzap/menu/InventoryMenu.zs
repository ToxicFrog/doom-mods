// Inventory select menu. Shows all the items players have received from the
// randomizer and lets them summon them.

#namespace GZAP;
#debug off;

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

    if (!::RandoState.Get()) {
      console.printf("%s", StringTable.Localize("$GZAP_MENU_ERROR_NOT_IN_GAME"));
      return;
    }

    PushText(" ");
    PushText("$GZAP_MENU_INVENTORY_TITLE", Font.CR_WHITE);
    PushText(" ");

    let state = ::RandoState.Get();
    for (int n = 0; n < state.items.Size(); ++n) {
      let item = state.items[n];
      if (item.GetLimit() == 0) continue;
      if (!item.category) continue; // Internal-only item not for player consumption
      let menu_item = new("::InventoryItem").Init(item);
      mDesc.mItems.Push(menu_item);
      menu_item.tt = PushTooltip(menu_item.FormatTooltip());
    }

    InitKeyDisplay();
    InitPeekDisplay();
    mDesc.mSelectedItem = -1;
  }

  override void Ticker() {
    let state = ::RandoState.Get();
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
    let region = ::RandoState.Get().GetCurrentRegion();
    if (!region) return;
    if (region.keys.CountUsed() == 0) return;

    PushText(" ");
    PushText("$GZAP_MENU_INVENTORY_KEYS", Font.CR_WHITE);
    PushText(" ");

    foreach (_, key : region.keys) {
      mDesc.mItems.Push(new("::KeyToggle").Init(region, key));
    }
  }

  void InitPeekDisplay() {
    let region = ::RandoState.Get().GetCurrentRegion();
    if (!region) return;

    bool did_header = false;
    foreach (loc : region.locations) {
      // Peeked locations are always sorted before everything else, so we can
      // stop as soon as we hit an unpeeked one.
      if (!loc.peek) break;
      if (!did_header) {
        PushText(" ");
        PushText("$GZAP_MENU_INVENTORY_HINTS");
        PushText(" ");
        did_header = true;
      }
      PushKeyValueText(loc.name, ::Util.FormatPeek(loc.peek.player, loc.peek.item, loc.flags));
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
      let state = ::RandoState.Get();
      int total = 0;
      for (int n = 0; n < state.items.Size(); ++n) {
        total += state.items[n].grabbed;
      }
      // If the user hasn't selected anything, and the item currently under the
      // cursor has at least one left, vend that immediately by sending an
      // increment followed by a commit.
      if (total == 0) {
        if (item.Remaining() == 0) {
          Menu.MenuSound("menu/invalid");
          return true;
        }
        EventHandler.SendNetworkCommand("ap-inv-grab-more", NET_STRING, item.typename);
      }
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

  virtual string FormatKeyName() {
    if (key_info.held) {
      return "\c[" .. ::Util.GetKeyColour(key_info.typename, "gray") .."]" .. key_info.tag;
    } else {
      return "\c[BLACK]"..key_info.tag.."\c-";
    }
  }

  virtual string FormatKeyStatus() {
    if (!key_info.held) {
      let hint = region.GetHint(key_info.FQIN());
      if (hint) {
        return ::Util.FormatHint(hint.player, hint.location);
      } else {
        return StringTable.Localize("$GZAP_MENU_KEY_MISSING");
      }
    }

    let suffix = "";
    if (key_info.held > 1) {
      suffix = string.format(" \c-(x%d)", key_info.held);
    }

    if (key_info.enabled) {
      return StringTable.Localize("$GZAP_MENU_KEY_ON") .. suffix;
    } else {
      return StringTable.Localize("$GZAP_MENU_KEY_OFF") .. suffix;
    }
  }
}

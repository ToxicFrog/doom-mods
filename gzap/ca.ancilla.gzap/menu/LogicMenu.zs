// Logic dashboard.
// Lets the player define regions and what their prerequisites are.

#namespace GZAP;
#debug off;

#include "../archipelago/RandoState.zsc"
#include "./CommonMenu.zsc"
#include "./RegionDefinitionMenu.zsc"

class ::LogicMenu : ::CommonMenu {
  ::KeyValueText subregion_name;
  ::KeyValueText subregion_prereqs;

  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.InitDynamic(null, desc);
    TooltipGeometry(0.0, 0.5, 0.2, 1.0, 0.5);
    TooltipAppearance("", "", "tfttbg");

    let apstate = ::PlayEventHandler.GetState();
    if (!apstate) {
      console.printf("%s", StringTable.Localize("$GZAP_MENU_ERROR_NOT_IN_GAME"));
      return;
    }

    let region = apstate.GetCurrentRegion();
    if (!region) {
      console.printf("%s", StringTable.Localize("$GZAP_MENU_ERROR_NOT_IN_RANDOMIZED_MAP"));
      return;
    }

    PushText(" ");
    PushText("$GZAP_MENU_LOGIC_TITLE", Font.CR_SAPPHIRE);
    PushText(" ");

    PushKeyValueText("$GZAP_MENU_LOGIC_CURRENT_MAP",
      apstate.GetCurrentRegion().map .. ": " .. level.LevelName, Font.CR_ICE);
    self.subregion_name = PushKeyValueText("$GZAP_MENU_LOGIC_CURRENT_SUBREGION", "", Font.CR_ICE);
    self.subregion_prereqs = PushKeyValueText("$GZAP_MENU_LOGIC_SUBREGION_PREREQS", "", Font.CR_ICE);
    PushText(" ");
    // We don't use OptionMenuItemSubmenu here because we can't customize the
    // colours for it.
    mDesc.mItems.Push(new("::RegionDefineButton").Init());
    mDesc.mItems.Push(new("::RegionClearButton").Init(apstate));
    // PushKeyValueText("Custom Prereqs", "PLACEHOLDER");
    PushKeyValueNetevent("Save subregions to tuning file", "[all subregions, all maps]", "ap-region-output", 0);

    if (apstate.subregion) {
      InitKeyDisplay(region, apstate.subregion);
      InitWeaponDisplay(apstate);
      InitSubregionDisplay(apstate, region);
    }
    mDesc.mSelectedItem = 7; // region define button
  }

  override void Ticker() {
    let apstate = ::PlayEventHandler.GetState();
    if (!apstate) {
      Close();
      return;
    }

    if (apstate.subregion) {
      self.subregion_name.value = apstate.subregion.name;
      self.subregion_prereqs.value = apstate.subregion.PrereqsAsString();
    } else {
      self.subregion_name.value = "\c[BLACK]none\c-";
      self.subregion_prereqs.value = "\c[BLACK]n/a\c-";
    }

    super.Ticker();
  }

  void PushPrereqToggle(::Subregion subregion, string name, string prereq) {
    mDesc.mItems.Push(new("::PrereqToggle").Init(subregion, name, prereq));
  }

  void InitFlagDisplay(::Subregion subregion) {
    PushText(" ");
    PushText("$GZAP_MENU_LOGIC_FLAGS", Font.CR_SAPPHIRE);
    PushText(" ");

    PushPrereqToggle(subregion, "$GZAP_MENU_LOGIC_SECRET", "flag/secret");
    PushTooltip("$GZAP_MENU_LOGIC_TT_SECRET");
    PushPrereqToggle(subregion, "$GZAP_MENU_LOGIC_UNREACHABLE", "flag/unreachable");
    PushTooltip("$GZAP_MENU_LOGIC_TT_UNREACHABLE");
  }

  void InitKeyDisplay(::Region region, ::Subregion subregion) {
    if (region.keys.CountUsed() == 0) return;

    PushText(" ");
    PushText("$GZAP_MENU_INVENTORY_KEYS", Font.CR_SAPPHIRE);
    PushText(" ");

    foreach (_, key : region.keys) {
      mDesc.mItems.Push(new("::KeyPrereqToggle").Init(subregion, key));
    }
    PushPrereqToggle(subregion, "$GZAP_MENU_LOGIC_ANYKEY", "key/*");
    PushTooltip("$GZAP_MENU_LOGIC_TT_ANYKEY");
  }

  void InitWeaponDisplay(::RandoState apstate) {
    PushText(" ");
    PushText("$GZAP_MENU_INVENTORY_WEAPONS", Font.CR_FIRE);
    PushText(" ");

    foreach (item : apstate.items) {
      if (item.IsWeapon()) {
        mDesc.mItems.Push(new("::WeaponPrereqToggle").Init(apstate.subregion, item));
      }
    }
  }

  void InitSubregionDisplay(::RandoState apstate, ::Region current_region) {
    if (!current_region.hub) {
      // No hub logic, so only display subregions from the current map.
      PushText(" ");
      PushText("$GZAP_MENU_LOGIC_REGIONS_IN_MAP", Font.CR_ICE);
      PushText(" ");
      foreach (name, subregion : current_region.subregions) {
        if (subregion == apstate.subregion) continue;
        PushPrereqToggle(
          apstate.subregion, subregion.name,
          "map/"..current_region.map.."/"..subregion.name);
      }
    } else {
      // Hub logic is in effect, so display all visited regions from the same
      // hubcluster as the current map.
      PushText(" ");
      PushText("$GZAP_MENU_LOGIC_REGIONS_IN_CLUSTER", Font.CR_ICE);
      PushText(" ");
      foreach (map,region : apstate.regions) {
        if (region.hub != current_region.hub || !region.visited) continue;
        PushPrereqToggle(apstate.subregion,
          "\c[SILVER]"..region.AccessFlagFQIN().."\c-", "map/"..region.map);
        foreach (name, subregion : region.subregions) {
          if (subregion == apstate.subregion) continue;
          PushPrereqToggle(apstate.subregion, subregion.name, "map/"..region.map.."/"..subregion.name);
        }
      }
    }
  }
}

class ::RegionDefineButton : ::KeyValueSelectable {
  ::RegionDefineButton Init() {
    self.mCentered = true;
    super.Init("$GZAP_MENU_LOGIC_CREATE_SUBREGION", "");
    return self;
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter) {
      Menu.MenuSound("menu/advance");
      Menu.GetCurrentMenu().Close();
      EventHandler.SendNetworkEvent("ap-region-menu");
      return true;
    }

    return super.MenuEvent(key, fromController);
  }
}

class ::RegionClearButton : ::KeyValueNetevent {
  ::RandoState apstate;

  ::RegionClearButton Init(::RandoState apstate) {
    self.apstate = apstate;
    self.mCentered = true;
    super.Init("$GZAP_MENU_LOGIC_CLEAR_SUBREGION", "", "ap-logic-menu", 0);
    return self;
  }

  override bool Selectable() { return !!apstate.subregion; }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter)
      EventHandler.SendNetworkEvent("ap-region-clear");
    return super.MenuEvent(key, fromController);
  }
}

class ::PrereqToggle : ::KeyValueSelectable {
  ::Subregion subregion;
  string name;
  string prereq;

  ::PrereqToggle Init(::Subregion subregion, string name, string prereq) {
    self.subregion = subregion;
    self.name = name;
    self.prereq = prereq;
    super.Init(FormatName(), FormatStatus());
    return self;
  }

  override bool Selectable() { return self.Enabled(); }
  virtual bool Enabled() { return true; }

  override void Ticker() {
    self.key = FormatName();
    self.value = FormatStatus();
    super.Ticker();
  }

  virtual string FormatName() {
    if (!self.Enabled()) {
      return "\c[BLACK]"..self.name.."\c-";
    } else {
      return self.name;
    }
  }

  virtual string FormatStatus() {
    if (!self.Enabled()) {
      return "\c[BLACK]X\c-";
    } else if (subregion.HasPrereq(self.prereq)) {
      return "\c[GREEN]+\c-";
    } else {
      return "\c[RED]-\c-";
    }
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter) {
      EventHandler.SendNetworkCommand("ap-toggle-prereq", NET_STRING, self.prereq);
      Menu.MenuSound("menu/change");
      return true;
    }

    return super.MenuEvent(key, fromController);
  }
}

class ::KeyPrereqToggle : ::PrereqToggle {
  ::RandoKey key_info;

  ::KeyPrereqToggle Init(::Subregion subregion, ::RandoKey key_info) {
    self.key_info = key_info;
    super.Init(subregion, key_info.tag, "key/"..key_info.typename);
    return self;
  }

  override bool Enabled() { return key_info.held; }

  override string FormatName() {
    if (Enabled()) {
      return "\c[" .. ::Util.GetKeyColour(key_info.typename, "gray") .."]" .. super.FormatName() .. "\c-";
    } else {
      return super.FormatName();
    }
  }
}

class ::ItemPrereqToggle : ::PrereqToggle {
  string prefix;
  ::RandoItem item;

  ::ItemPrereqToggle Init(::Subregion subregion, string prefix, ::RandoItem item) {
    self.item = item;
    super.Init(subregion, item.tag, prefix.."/"..item.typename);
    return self;
  }

  override bool Enabled() { return item.total > 0; }
}

// A tri-state toggle for weapons between ignored, preferred, required.
// Preferred incorporates it into weapon logic for this area.
// Required makes it a hard requirement that cannot be turned off.
class ::WeaponPrereqToggle : ::PrereqToggle {
  ::RandoItem weapon;

  ::WeaponPrereqToggle Init(::Subregion subregion, ::RandoItem weapon) {
    self.weapon = weapon;
    super.Init(subregion, weapon.tag, "weapon/"..self.weapon.typename);
    return self;
  }

  override bool Enabled() { return self.weapon.total > 0; }
  string WantPrereq() { return string.format("weapon/%s/want", self.weapon.typename); }
  string NeedPrereq() { return string.format("weapon/%s/need", self.weapon.typename); }
  bool IsWanted() { return subregion.HasPrereq(WantPrereq()); }
  bool IsNeeded() { return subregion.HasPrereq(NeedPrereq()); }

  override string FormatStatus() {
    if (!self.Enabled()) {
      return "\c[BLACK]X\c-";
    } else if (IsWanted()) {
      return "\c[YELLOW]?\c-";
    } else if (IsNeeded()) {
      return "\c[GREEN]+\c-";
    } else {
      return "\c[RED]-\c-";
    }
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter) {
      if (IsWanted()) {
        EventHandler.SendNetworkCommand("ap-toggle-prereq", NET_STRING, WantPrereq());
        EventHandler.SendNetworkCommand("ap-toggle-prereq", NET_STRING, NeedPrereq());
      } else if (IsNeeded()) {
        EventHandler.SendNetworkCommand("ap-toggle-prereq", NET_STRING, NeedPrereq());
      } else {
        EventHandler.SendNetworkCommand("ap-toggle-prereq", NET_STRING, WantPrereq());
      }
      Menu.MenuSound("menu/change");
      return true;
    }

    return super.MenuEvent(key, fromController);
  }
}

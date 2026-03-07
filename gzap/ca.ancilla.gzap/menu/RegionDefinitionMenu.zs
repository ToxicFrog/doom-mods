// Region definition menu. Normally accessed via the logic dashboard.
// Lets the player define a new region by entering its name, or activate an
// existing region by selecting it from a list.

#namespace GZAP;
#debug off;

#include "../archipelago/RandoState.zsc"
#include "./CommonMenu.zsc"

class ::RegionDefinitionMenu : ::CommonMenu {
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
      console.printf("%s", StringTable.Localize("$GZAP_MENU_ERROR_NOT_RANDOMIZED_MAP"));
      return;
    }

    PushText(" ");
    PushText("$GZAP_MENU_REGION_DEFINE", Font.CR_SAPPHIRE);
    PushText(" ");

    mDesc.mItems.Push(new("::RegionNameEntry").Init());

    PushText(" ");
    PushText("$GZAP_MENU_REGION_ACTIVATE", Font.CR_SAPPHIRE);
    PushText(" ");

    InitSubregionDisplay(apstate, region);

    mDesc.mSelectedItem = 3; // region name entry
  }

  // Largely copied from LogicMenu, but creates different entry types and only
  // displays regions from the same map.
  void InitSubregionDisplay(::RandoState apstate, ::Region current_region) {
    foreach (name, subregion : current_region.subregions) {
      if (subregion == apstate.subregion) continue;
      mDesc.mItems.Push(new("::ActivateRegionButton").Init(subregion.name));
    }
  }
}

class ::RegionNameEntry : OptionMenuItemTextField {
	OptionMenuItemTextField Init() {
    super.Init("$GZAP_MENU_REGION_ENTER_NAME", "", null);
    mEnter = null;
    return self;
  }

  override bool,string GetString(int i) {
    if (!i) return false,"";
    return true,"<<placeholder>>";
  }

	override bool SetString(int i, string s) {
		if (i == 0) {
      EventHandler.SendNetworkEvent("ap-region/"..s);
      Menu.GetCurrentMenu().Close();
      EventHandler.SendNetworkEvent("ap-logic-menu");
      return true;
    } else {
      return false;
    }
  }
}

class ::ActivateRegionButton : ::KeyValueNetevent {
  string region_name;

  ::ActivateRegionButton Init(string name) {
    self.region_name = name;
    super.Init(name, "", "ap-logic-menu", 0);
    return self;
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key == Menu.MKey_Enter)
      EventHandler.SendNetworkEvent("ap-region/"..self.region_name);
    return super.MenuEvent(key, fromController);
  }
}

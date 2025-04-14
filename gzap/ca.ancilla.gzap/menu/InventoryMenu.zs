
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

    PushText(" ");
    PushText("$GZAP_MENU_INVENTORY_TITLE", Font.CR_WHITE);
    PushText(" ");

    let state = ::PlayEventHandler.GetState();
    for (int n = 0; n < state.items.Size(); ++n) {
      let item = state.items[n];
      if (item.held > 0) {
        PushKeyValueNetevent(item.tag, string.format("%d", item.held), "ap-use-item", n);
        PushTooltip(string.format("Name: %s\nType: %s\nCategory: %s\nHeld/Found: %d/%d",
          item.tag, item.typename, item.category, item.held, item.total));
      }
    }

    if (mDesc.mSelectedItem >= mDesc.mItems.Size()) {
      mDesc.mSelectedItem = -1;
    }
  }
}

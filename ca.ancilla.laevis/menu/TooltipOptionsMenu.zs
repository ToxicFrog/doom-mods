#namespace TFLV::Menu;

class ::TooltipOptionsMenu : OptionMenu {
  array<string> tooltips;

  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);

    // Steal the descriptor's list of menu items, then rebuild it containing
    // only the items we want to display.
    array<OptionMenuItem> items;
    items.Move(desc.mItems);

    int startblock = -1;
    for (uint i = 0; i < items.size(); ++i) {
      if (items[i] is "OptionMenuItemTooltipBlockStart") {
        startblock = desc.mItems.size();
      } else if (items[i] is "OptionMenuItemTooltipBlockEnd") {
        startblock = -1;
      } else if (items[i] is "OptionMenuItemTooltip") {
        let tt = OptionMenuItemTooltip(items[i]);
        AddTooltip(
            startblock >= 0 ? startblock : desc.mItems.size()-1,
            desc.mItems.size()-1, tt.tooltip);
      } else {
        desc.mItems.push(items[i]);
      }
    }
  }

  void AddTooltip(uint first, uint last, string tooltip) {
    while (tooltips.size() <= last) {
      tooltips.push("");
    }
    for (uint i = first; i <= last; ++i) {
      if (tooltips[i].length() > 0) {
        tooltips[i] = tooltips[i].."\n"..tooltip;
      } else {
        tooltips[i] = tooltip;
      }
    }
  }

  override void Drawer() {
    super.Drawer();
    let selected = mDesc.mSelectedItem;
    if (selected >= 0 && selected < tooltips.size() && tooltips[selected].length() > 0) {
      DrawTooltip(tooltips[selected]);
    }
  }

  void DrawTooltip(string tt) {
    let lines = newsmallfont.BreakLines(tt, screen.GetWidth()/3);
    let lh = newsmallfont.GetHeight();
    for (uint i = 0; i < lines.count(); ++i) {
      screen.DrawText(
        newsmallfont, Font.CR_WHITE,
        newsmallfont.GetCharWidth(0x20), lh/2+i*lh, lines.StringAt(i));
    }
  }
}

class OptionMenuItemTooltipBlockStart : OptionMenuItem {
  OptionMenuItemTooltipBlockStart Init() { return self; }
}
class OptionMenuItemTooltipBlockEnd : OptionMenuItem {
  OptionMenuItemTooltipBlockEnd Init() { return self; }
}

class OptionMenuItemTooltip : OptionMenuItem {
  string tooltip;

  OptionMenuItemTooltip Init(string tooltip) {
    self.tooltip = tooltip;
    super.init("", "");
    return self;
  }
}

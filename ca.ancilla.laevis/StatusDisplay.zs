class TFLV_StatusDisplay : OptionMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.Init(parent, desc);
    mDesc.mItems.Clear();

    let pawn = PlayerPawn(players[consoleplayer].mo);
    let pps = TFLV_PerPlayerStats.GetStatsFor(pawn);

    TFLV_CurrentStats stats;
    pps.GetCurrentStats(stats);
    let info = pps.GetInfoForCurrentWeapon();

    PushText("", Font.CR_GOLD);
    PushText("Player Stats", Font.CR_GOLD);
    PushInfo("Level", string.format("%d (%d/%d XP)", stats.plvl, stats.pxp, stats.pmax));
    PushInfo("Damage Dealt", string.format("%d%%", stats.pdmg * 100));
    PushInfo("Damage Taken", string.format("%d%%", stats.pdef * 100));

    PushText("", Font.CR_GOLD);
    PushText("Weapon Stats", Font.CR_GOLD);
    PushInfo("Type", string.format("%s (%s)", info.weapon.GetTag(), info.weapon.GetClassName()));
    PushInfo("Level", string.format("%d (%d/%d XP)", stats.wlvl, stats.wxp, stats.wmax));
    PushInfo("Damage Dealt", string.format("%d%% (%d%% total)", stats.wdmg * 100, stats.pdmg * stats.wdmg * 100));

    if (info.effects.size() > 0) {
      PushText("", Font.CR_GOLD);
      PushText("Weapon Effects", Font.CR_GOLD);
      for (uint i = 0; i < info.effects.size(); ++i) {
        if (info.currentEffect == i) {
          PushEffect(info.effects[i], i, true);
          mDesc.mSelectedItem = mDesc.mItems.Size() - 1;
        } else {
          PushEffect(info.effects[i], i, false);
        }
      }
    }
  }

  void PushText(string text, uint colour) {
    mDesc.mItems.Push(new("OptionMenuItemStaticText").InitDirect(text, colour));
  }

  void PushInfo(string key, string value) {
    mDesc.mItems.Push(new("OptionMenuItemStaticInfo").Init(key, value));
  }

  void PushEffect(string effect, uint index, bool isDefault) {
    mDesc.mItems.Push(new("OptionMenuItemEffect").Init(effect, index, isDefault));
  }

  override int GetIndent() {
    return super.GetIndent() - 200 * CleanXFac_1;
  }
}

class OptionMenuItemStaticInfo : OptionMenuItem {
  string key;
  string value;

  OptionMenuItemStaticInfo Init(string key_, string value_) {
    key = key_;
    value = value_;
    super.Init(key, "");
    return self;
  }

  override bool Selectable() { return false; }

  override int Draw(OptionMenuDescriptor d, int y, int indent, bool selected) {
    drawLabel(indent, y, Font.CR_RED);
    drawValue(indent, y, Font.CR_RED, value);
    return indent;
  }
}

class OptionMenuItemEffect : OptionMenuItem {
  // Effect ID and displayable effect information.
  bool wasDefault;
  int index;
  string effect;
  string effectName;
  string effectDesc;

  OptionMenuItemEffect Init(string effect_, int index_, bool wasDefault_) {
    wasDefault = wasDefault_;
    index = index_;
    effect = effect_;
    effectName = TFLV_Util.GetEffectTitle(effect);
    effectDesc = TFLV_Util.GetEffectDesc(effect);
    super.Init(effectName, "");
    return self;
  }

  override bool MenuEvent(int key, bool fromController) {
    if (key != Menu.MKey_Enter)
      return super.MenuEvent(key, fromController);

    Menu.MenuSound("menu/choose");
    console.printf("Effect chosen: %s", effect);
    EventHandler.SendNetworkEvent("laevis_select_effect", index);
    Menu.GetCurrentMenu().Close();
    return true;
  }

  override int Draw(OptionMenuDescriptor d, int y, int indent, bool selected) {
    uint colour;
    if (wasDefault) {
      colour = selected ? Font.CR_YELLOW : Font.CR_ORANGE;
    } else {
      colour = selected ? Font.CR_RED : Font.CR_DARKRED;
    }
    drawLabel(indent, y, colour);
    drawValue(indent, y, colour, effectDesc);
    return indent;
  }
}

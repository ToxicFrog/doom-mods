#namespace TFLV;

// Matches the rarity levels in Legendoom.
enum ::LDRarity {
  RARITY_MUNDANE = -1,
  RARITY_COMMON, RARITY_UNCOMMON, RARITY_RARE, RARITY_EPIC
}

class ::LegendoomUtil {
  static ::LDRarity GetWeaponRarity(Actor act, string prefix) {
    if (act.FindInventory(prefix.."LegendaryEpic")) {
      return RARITY_EPIC;
    } else if (act.FindInventory(prefix.."LegendaryRare")) {
      return RARITY_RARE;
    } else if (act.FindInventory(prefix.."LegendaryUncommon")) {
      return RARITY_UNCOMMON;
    } else if (act.FindInventory(prefix.."LegendaryCommon")) {
      return RARITY_COMMON;
    } else {
      return RARITY_MUNDANE;
    }
  }

  static Inventory FindItemWithPrefix(Actor act, string prefix) {
    // GetClassName() isn't consistent about case, so lowercase everything before
    // we compare it to avoid, e.g., "LDPistolEffectActive" comparing different
    // to "ldpistolEffectActive".
    prefix = prefix.MakeLower();
    for (Inventory item = act.Inv; item; item = item.Inv) {
      string cls = item.GetClassName();
      cls = cls.MakeLower();
      if (cls.IndexOf(prefix) == 0) {
        return item;
      }
    }
    return null;
  }

  static string GetActiveWeaponEffect(Actor act, string prefix) {
    Inventory item = FindItemWithPrefix(act, prefix.."Effect_");
    if (item) return item.GetClassName();
    return "";
  }

  static string GetEffectTitle(string effect) {
    string suffix = effect.Mid(effect.RightIndexOf("_")+1);
    return StringTable.Localize("$LD_FX_TITLE_"..suffix);
  }

  // Gets the effect description without flavour text.
  static string GetEffectDesc(string effect) {
    string full = GetEffectDescFull(effect);
    int nl = full.IndexOf("\n");
    if (nl >= 0) {
      return full.left(nl);
    } else {
      return full;
    }
  }

  // Gets the effect description including flavour text.
  static string GetEffectDescFull(string effect) {
    string suffix = effect.Mid(effect.RightIndexOf("_")+1);
    return StringTable.Localize("$LD_FX_DESCR_"..suffix);
  }

}

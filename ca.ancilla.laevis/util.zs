// An inventory object that can't be dropped and you can only have one of.
// Name comes from Crossfire's force objects used to track spell effects and
// the like.
class TFLV_Force : Inventory {
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +Inventory.IgnoreSkill;
    +Inventory.Untossable;
  }
}

// Matches the rarity levels in Legendoom.
enum TFLV_LD_Rarity {
  RARITY_MUNDANE = -1,
  RARITY_COMMON, RARITY_UNCOMMON, RARITY_RARE, RARITY_EPIC
}

class TFLV_Util : Object {
  static TFLV_LD_Rarity GetWeaponRarity(Actor act, string prefix) {
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

  static string GetWeaponEffectName(Actor act, string prefix) {
    Inventory item = FindItemWithPrefix(act, prefix.."Effect_");
    if (item) return item.GetClassName();
    return "";
  }

  static string GetAbilityTitle(string ability) {
    string suffix = ability.Mid(ability.RightIndexOf("_")+1);
    return StringTable.Localize("$LD_FX_TITLE_"..suffix);
  }

  // Gets the ability description without flavour text;
  static string GetAbilityDesc(string ability) {
    string full = GetAbilityDescFull(ability);
    int nl = full.IndexOf("\n");
    if (nl >= 0) {
      return full.left(nl);
    } else {
      return full;
    }
  }

  // Gets the ability description including flavour text.
  static string GetAbilityDescFull(string ability) {
    string suffix = ability.Mid(ability.RightIndexOf("_")+1);
    return StringTable.Localize("$LD_FX_DESCR_"..suffix);
  }
}

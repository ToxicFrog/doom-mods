// The parts of WeaponInfo that are specific to Legendoom.
#namespace TFLV;

class ::LegendoomWeaponInfo : Object play {
  ::WeaponInfo info;
  uint effectSlots;
  uint maxRarity;
  bool canReplaceEffects;
  array<string> effects;
  int currentEffect;
  string currentEffectName;

  void Init(::WeaponInfo info) {
    self.info = info;
    currentEffect = -1;
    currentEffectName = "";
    effects.Clear();
  }

  void Rebind(::WeaponInfo info) {
    string LDWeaponType = "LDWeapon";
    if (info.wpn is LDWeaponType) {
      // If it's a Legendoom weapon, calling this should be safe; it'll keep
      // its current effects, but inherit the rarity of the new weapon. If the
      // new weapon has a new effect on it, that'll be added to the effect list
      // even if it exceeds the maximum.
      // TODO: in the latter case, trigger the LD levelup menu until the effect
      // list fits again.
      InitLegendoom();
    } else {
      effectSlots = 0;
    }
  }

  void InitLegendoom() {
    string prefix = info.wpn.GetClassName();

    maxRarity = ::LegendoomUtil.GetWeaponRarity(info.wpn.owner, prefix);
    canReplaceEffects = GunRarityMatchesSetting(bonsai_which_guns_can_replace, maxRarity);
    if (GunRarityMatchesSetting(bonsai_which_guns_can_learn, maxRarity)) {
      effectSlots = bonsai_base_ld_effect_slots
        + maxRarity * bonsai_bonus_ld_effect_slots;
    } else {
      effectSlots = 0;
    }
    if (bonsai_ignore_gun_rarity) {
      maxRarity = RARITY_EPIC;
    } else {
      maxRarity = max(RARITY_COMMON, maxRarity);
    }

    // And they might start with an effect, so we should record that.
    string effect = ::LegendoomUtil.GetActiveWeaponEffect(info.wpn.owner, prefix);
    if (effects.find(effect) != effects.size()) {
      currentEffect = effects.find(effect);
      currentEffectName = ::LegendoomUtil.GetEffectTitle(effect);
    } else if (effect != "") {
      effects.push(effect);
      currentEffect = effects.size()-1;
      currentEffectName = ::LegendoomUtil.GetEffectTitle(effect);
    } else {
      currentEffect = -1;
      currentEffectName = "";
    }

    DEBUG("%s: effects=%d, rarity=%d, effect=%s",
        info.wpn.GetTag(), effectSlots, maxRarity, effect);
  }

  void CycleEffect() {
    if (effects.size() == 0) return;
    SelectEffect((currentEffect + 1) % effects.size());
  }

  void SelectEffect(uint index) {
    if (effects.size() <= index) return;
    //if (index == currentEffect) return;

    if (currentEffect >= 0)
      info.wpn.owner.TakeInventory(effects[currentEffect], 1);
    currentEffect = index;
    currentEffectName = ::LegendoomUtil.GetEffectTitle(effects[currentEffect]);
    info.wpn.owner.GiveInventory(effects[currentEffect], 1);
  }

  void DiscardEffect(uint index) {
    DEBUG("DiscardEffect, total=%d, index=%d, current=%d",
        effects.size(), index, currentEffect);
    if (effects.size() <= index) return;
    if (index == currentEffect) {
      // The effect they want to discard is the current one.
      // Remove the effect now, then CycleEffect afterwards to select a new valid one.
      info.wpn.owner.TakeInventory(effects[index], 1);
      effects.Delete(index);
      CycleEffect();
    } else if (index < currentEffect) {
      // They want to discard an effect before the current one, which will result
      // in later effects being renumbered.
      currentEffect--;
    effects.Delete(index);
    }
  }

  bool GunRarityMatchesSetting(::WhichGuns setting, ::LDRarity rarity) {
    if (rarity == RARITY_MUNDANE) {
      return setting & 1;
    } else {
      return setting & 2;
    }
  }

  void DumpToConsole() {
    if (!::Settings.have_legendoom()) return;
    if (effectSlots == 0) {
      console.printf("(no Legendoom data)");
      return;
    }
    console.printf("Legendoom: %d slots, %s replace, rarity: %d",
      effectSlots, (canReplaceEffects ? "can" : "can't"), maxRarity);
    for (uint i = 0; i < effects.size(); ++i) {
      console.printf("    %s (%s)",
        ::LegendoomUtil.GetEffectTitle(effects[i]),
        ::LegendoomUtil.GetEffectDesc(effects[i]));
    }
  }
}

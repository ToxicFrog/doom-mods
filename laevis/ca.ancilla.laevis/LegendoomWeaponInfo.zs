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
    if (info.weapon is LDWeaponType) {
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
    string prefix = info.weapon.GetClassName();

    maxRarity = ::Util.GetWeaponRarity(info.weapon.owner, prefix);
    canReplaceEffects = GunRarityMatchesSetting(::Settings.which_guns_can_replace(), maxRarity);
    if (GunRarityMatchesSetting(::Settings.which_guns_can_learn(), maxRarity)) {
      effectSlots = ::Settings.base_ld_effect_slots()
        + maxRarity * ::Settings.bonus_ld_effect_slots();
    } else {
      effectSlots = 0;
    }
    if (::Settings.ignore_gun_rarity()) {
      maxRarity = RARITY_EPIC;
    } else {
      maxRarity = max(RARITY_COMMON, maxRarity);
    }

    // And they might start with an effect, so we should record that.
    string effect = ::Util.GetActiveWeaponEffect(info.weapon.owner, prefix);
    if (effects.find(effect) != effects.size()) {
      currentEffect = effects.find(effect);
      currentEffectName = ::Util.GetEffectTitle(effect);
    } else if (effect != "") {
      effects.push(effect);
      currentEffect = effects.size()-1;
      currentEffectName = ::Util.GetEffectTitle(effect);
    } else {
      currentEffect = -1;
      currentEffectName = "";
    }

    DEBUG("%s: effects=%d, rarity=%d, effect=%s",
        info.weapon.GetTag(), effectSlots, maxRarity, effect);
  }

  void CycleEffect() {
    SelectEffect((currentEffect + 1) % effects.size());
  }

  void SelectEffect(uint index) {
    if (effects.size() <= index) return;
    //if (index == currentEffect) return;

    if (currentEffect >= 0)
      info.weapon.owner.TakeInventory(effects[currentEffect], 1);
    currentEffect = index;
    currentEffectName = ::Util.GetEffectTitle(effects[currentEffect]);
    info.weapon.owner.GiveInventory(effects[currentEffect], 1);
  }

  void DiscardEffect(uint index) {
    DEBUG("DiscardEffect, total=%d, index=%d, current=%d",
        effects.size(), index, currentEffect);
    if (effects.size() <= index) return;
    if (index == currentEffect) {
      // The effect they want to discard is the current one.
      // Remove the effect now, then CycleEffect afterwards to select a new valid one.
      info.weapon.owner.TakeInventory(effects[index], 1);
      effects.Delete(index);
      CycleEffect();
    } else if (index < currentEffect) {
      // They want to discard an effect before the current one, which will result
      // in later effects being renumbered.
      currentEffect--;
    effects.Delete(index);
    }
  }

  bool GunRarityMatchesSetting(::WhichGuns setting, ::LD_Rarity rarity) {
    if (rarity == RARITY_MUNDANE) {
      return setting & 1;
    } else {
      return setting & 2;
    }
  }

  void DumpToConsole() {
    if (effectSlots == 0) {
      console.printf("(no Legendoom data)");
      return;
    }
    console.printf("Legendoom: %d slots, %s replace, rarity: %d",
      effectSlots, (canReplaceEffects ? "can" : "can't"), maxRarity);
    for (uint i = 0; i < effects.size(); ++i) {
      console.printf("    %s (%s)",
        ::Util.GetEffectTitle(effects[i]),
        ::Util.GetEffectDesc(effects[i]));
    }
  }
}

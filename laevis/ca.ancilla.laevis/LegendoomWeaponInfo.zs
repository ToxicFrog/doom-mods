// The parts of WeaponInfo that are specific to Legendoom.
#namespace TFLV;
#debug on;

class ::WeaponInfo : Object play {
  Weapon wpn;
  string wpnClass;
  uint effectSlots;
  uint maxRarity;
  bool canReplaceEffects;
  array<string> effects; // Class names of effect tokens, e.g. "LDShotgunEffect_Scanner"
  int currentEffect;
  string currentEffectName;

  void Init(Weapon wpn) {
    currentEffect = -1;
    currentEffectName = "";
    effects.Clear();
    Rebind(wpn);
  }

  bool CanRebindTo(Weapon wpn) {
    return wpn && wpn.GetClassName() == wpnClass;
  }

  void Rebind(Weapon wpn) {
    DEBUG("WeaponInfo::Bind(%s)", wpnClass);
    self.wpn = wpn;
    self.wpnClass = wpn.GetClassName();
    if (wpn is "LDWeapon") {
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
    string prefix = wpn.GetClassName();

    maxRarity = ::LegendoomUtil.GetWeaponRarity(wpn.owner, prefix);
    canReplaceEffects = GunRarityMatchesSetting(laevis_which_guns_can_replace, maxRarity);
    if (GunRarityMatchesSetting(laevis_which_guns_can_learn, maxRarity)) {
      effectSlots = laevis_base_ld_effect_slots
        + maxRarity * laevis_bonus_ld_effect_slots;
    } else {
      effectSlots = 0;
    }
    if (laevis_ignore_gun_rarity) {
      maxRarity = RARITY_EPIC;
    } else {
      maxRarity = max(RARITY_COMMON, maxRarity);
    }

    // FIXME: bug here on initial items and when picking up an LDEffect that
    // gets added on to an existing, non-legendary weapon.
    // In the former case, we see the weapon pickup and rebuild the info before
    // we get the effect pickup.
    // In the latter case, we don't see a weapon pickup at all because the
    // weapon doesn't get picked up, only the effect.
    // We should probably trigger a rebind on effect pickups to make sure they
    // get recorded in the effect list properly.
    // And they might start with an effect, so we should record that.
    string effect = ::LegendoomUtil.GetActiveWeaponEffect(wpn.owner, prefix);
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
        wpn.GetTag(), effectSlots, maxRarity, effect);
  }

  void AddEffect(string effect) {
    if (effects.find(effect) == effects.size()) {
      console.printf("Your %s learned the ability \"%s\"!",
        wpn.GetTag(), ::LegendoomUtil.GetEffectTitle(effect));
      effects.push(effect);
    } else {
      console.printf("Your %s already knows the ability \"%s\".",
        wpn.GetTag(), ::LegendoomUtil.GetEffectTitle(effect));
    }
  }

  void CycleEffect() {
    if (effects.size() == 0) return;
    SelectEffect((currentEffect + 1) % effects.size());
  }

  // TODO -- we should put passive effects in their own section, and make them
  // part of the player's inventory at all times, since they usually have effects
  // whether or not the weapon is wielded and don't interfere with firing behaviour.
  // FIXME -- we need to make the weapon's rarity level consistent with the
  // rarity of the effect it currently has or we get weird glitchy rendering
  // artefacts.
  void SelectEffect(uint index) {
    if (effects.size() <= index) return;
    //if (index == currentEffect) return;

    if (currentEffect >= 0)
      wpn.owner.TakeInventory(effects[currentEffect], 1);
    currentEffect = index;
    currentEffectName = ::LegendoomUtil.GetEffectTitle(effects[currentEffect]);
    wpn.owner.GiveInventory(effects[currentEffect], 1);
    console.printf("%s: %s", currentEffectName, ::LegendoomUtil.GetEffectDesc(effects[currentEffect]));
  }

  void DiscardEffect(uint index) {
    DEBUG("DiscardEffect, total=%d, index=%d, current=%d",
        effects.size(), index, currentEffect);
    if (effects.size() <= index) return;
    if (index == currentEffect) {
      // The effect they want to discard is the current one.
      // Remove the effect now, then CycleEffect afterwards to select a new valid one.
      wpn.owner.TakeInventory(effects[index], 1);
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

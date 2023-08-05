// The parts of WeaponInfo that are specific to Legendoom.
#namespace TFLV;
#debug off;

class ::LegendoomEffect : Object play {
  string name;        // Class name of effect, e.g. LDShotgunEffect_Scanner
  string weapon;      // Class name of weapon, e.g. LDShotgun
  ::LDRarity rarity;  // never RARITY_MUNDANE
  string rarityName;  // LDShotgunLegendaryEpic, etc
  bool passive;       // true if this is a passive effect that can be always-on

  static ::LegendoomEffect Create(string name, string weapon, ::LDRarity rarity) {
    let effect = new("::LegendoomEffect");
    effect.name = name;
    effect.weapon = weapon;
    effect.rarity = rarity;
    effect.rarityName = weapon .. ::LegendoomUtil.GetRarityName(rarity, weapon);
    effect.passive = ::LegendoomUtil.GetEffectDescFull(name).IndexOf("[PASSIVE]") >= 0;
    return effect;
  }

  string Title() const { return ::LegendoomUtil.GetEffectTitle(self.name); }
  string Desc() const { return ::LegendoomUtil.GetEffectDesc(self.name); }
}

class ::WeaponInfo : Object play {
  Weapon wpn;
  string wpnClass;
  uint effectSlots;
  uint xp;
  array<::LegendoomEffect> effects;
  array<::LegendoomEffect> passives; // Always on
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

    effectSlots = laevis_base_effect_slots;

    AddEffectFromActor(wpn.owner);
    if (currentEffect >= effects.size()) {
      currentEffect = effects.size()-1;
    }
    if (effects.size() > 0) {
      currentEffectName = effects[currentEffect].name;
    }
    EnablePassives();
  }

  bool HasEffect(string effect) {
    for (uint i = 0; i < effects.size(); ++i) {
      if (effects[i].name == effect) return true;
    }
    for (uint i = 0; i < passives.size(); ++i) {
      if (passives[i].name == effect) return true;
    }
    return false;
  }

  // Ingest an effect from an actor, either the player who has just picked up a
  // new weapon+effect or from a pickup on the ground.
  // We assume that the caller has already found the right WeaponInfo to call
  // this on and thus don't double-check prefix or anything.
  // Returns true if a new effect was ingested, false if it wasn't (either because
  // there wasn't one to ingest, or because we already had this one).
  ::LDRarity AddEffectFromActor(Actor act) {
    DEBUG("AddEffectFromActor: %s", TAG(act));
    let token = ::LegendoomUtil.FindItemWithPrefix(act, wpnClass.."Effect_");
    if (!token) {
      // actor doesn't have an effect in it (or maybe wrong weapon?)
      DEBUG("no token!");
      return RARITY_MUNDANE;
    }
    let name = token.GetClassName();
    if (HasEffect(name)) {
      // TODO - count this as a discard and potentially upgrade the weapon
      console.printf("Your %s already contains the ability \"%s\".",
        wpn.GetTag(), ::LegendoomUtil.GetEffectTitle(name));
      return RARITY_MUNDANE;
    }

    let effect = ::LegendoomEffect.Create(
      name, self.wpnClass,
      ::LegendoomUtil.GetWeaponRarity(act, self.wpnClass));

    // TODO -- check capacity limits
    if (effect.passive) {
      passives.push(effect);
    } else {
      effects.push(effect);
      if (effects.size() == 1) SelectEffect(0);
    }
    EnablePassives();
    console.printf("Your %s absorbed the ability \"%s\"!",
      wpn.GetTag(), effect.Title());
    return effect.rarity;
  }

  void CycleEffect() {
    if (effects.size() == 0) return;
    SelectEffect((currentEffect + 1) % effects.size());
  }

  void SelectEffect(uint index) {
    if (effects.size() <= index) return;
    //if (index == currentEffect) return;

    if (currentEffect >= 0) {
      DisableEffect(effects[currentEffect]);
    }
    currentEffect = index;
    currentEffectName = effects[currentEffect].Title();
    EnableEffect(effects[currentEffect]);
    console.printf("%s: %s", currentEffectName, effects[currentEffect].Desc());
  }

  void DisableEffect(::LegendoomEffect effect) {
    DEBUG("DisableEffect, idx=%d size=%d", currentEffect, effects.size());
    wpn.owner.TakeInventory(effect.name, 999);
    wpn.owner.TakeInventory(effect.rarityName, 999);
  }

  void EnableEffect(::LegendoomEffect effect) {
    DEBUG("EnableEffect, idx=%d size=%d", currentEffect, effects.size());
    wpn.owner.GiveInventory(effect.name, 1);
    wpn.owner.GiveInventory(effect.rarityName, 1);
  }

  void EnablePassives() {
    for (uint i = 0; i < passives.size(); ++i) {
      DEBUG("Activating %s", passives[i].name);
      wpn.owner.TakeInventory(passives[i].name, 999);
      wpn.owner.GiveInventory(passives[i].name, 1);
    }
  }

  void DiscardEffect(uint index) {
    DEBUG("DiscardEffect, total=%d, index=%d, current=%d",
        effects.size(), index, currentEffect);
    if (effects.size() <= index) return;
    if (index == currentEffect) {
      // The effect they want to discard is the current one.
      // Remove the effect now, then CycleEffect afterwards to select a new valid one.
      DisableEffect(effects[index]);
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
}

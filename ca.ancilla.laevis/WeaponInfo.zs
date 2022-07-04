// Info about a single weapon. These are held by the PerPlayerStats and each
// one records information about one of the player's weapons.
// It's also responsible for handling weapon level-ups.
#namespace TFLV;

class ::WeaponInfo : Object play {
  // At the moment "weapon" is used both as a convenient way to remember a reference
  // to the weapon itself, and as the key for the info lookup when the caller has
  // a weapon but not the WeaponInfo.
  Weapon weapon;
  string weaponType;
  ::Upgrade::UpgradeBag upgrades;
  uint XP;
  uint maxXP;
  uint level;
  // Tracking for how much this gun does hitscans vs. projectiles.
  // Use doubles rather than uints so that at high values it saturates rather
  // than overflowing.
  double hitscan_shots;
  double projectile_shots;

  // Legendoom integration fields.
  uint effectSlots;
  uint maxRarity;
  bool canReplaceEffects;
  array<string> effects;
  int currentEffect;
  string currentEffectName;

  // Called when a new WeaponInfo is created. This should initialize the entire object.
  void Init(Actor wpn) {
    self.weapon = Weapon(wpn);
    self.weaponType = wpn.GetClassName();
    upgrades = new("::Upgrade::UpgradeBag");
    XP = 0;
    level = 0;
    maxXP = GetXPForLevel(level+1);
    DEBUG("WeaponInfo initialize, class=%s level=%d xp=%d/%d",
        weaponType, level, XP, maxXP);

    currentEffect = -1;
    currentEffectName = "";
    effects.Clear();
    string LDWeaponType = "LDWeapon";
    if (wpn is LDWeaponType) {
      InitLegendoom();
    } else {
      effectSlots = 0;
    }
  }

  // Called when this WeaponInfo is being reassociated with a new weapon. It
  // should keep most of its stats.
  void Rebind(Actor wpn) {
    self.weapon = Weapon(wpn);
    if (self.weaponType != wpn.GetClassName()) {
      // Rebinding to a weapon of an entirely different type. Reset the attack
      // modality inference counters.
      self.weaponType = wpn.GetClassName();
      hitscan_shots = 0;
      projectile_shots = 0;
    }
    string LDWeaponType = "LDWeapon";
    if (wpn is LDWeaponType) {
      // If it's a Legendoom weapon, calling this should be safe; it'll keep
      // its current effects, but inherit the rarity of the new weapon. If the
      // new weapon has a new effect on it, that'll be added to the effect list
      // even if it exceeds the maximum.
      // TODO: in the latter case, trigger the LD levelup menu until the effect
      // list fits again.
      InitLegendoom();
    }
  }

  // Heuristics for guessing whether this is a projectile or hitscan weapon.
  // Note that for some weapons, both of these may return true, e.g. in the case
  // of a weapon that has a hitscan primary and projectile alt-fire that both
  // get used frequency.
  // The heuristic we use is that if more than 20% of the attacks made with this
  // weapon are hitscan, it's a hitscan weapon, and similarly for projectile attacks.
  // We have this threshold to limit false positives in the case of e.g. mods
  // that add offhand grenades that get attributed to the current weapon, or
  // weapons that have a projectile alt-fire that is used only very rarely.
  bool IsHitscanWeapon() {
    return hitscan_shots / 4 > projectile_shots;
  }

  bool IsProjectileWeapon() {
    return projectile_shots / 4 > hitscan_shots;
  }

  bool GunRarityMatchesSetting(::WhichGuns setting, ::LD_Rarity rarity) {
    if (rarity == RARITY_MUNDANE) {
      return setting & 1;
    } else {
      return setting & 2;
    }
  }

  void InitLegendoom() {
    string prefix = weapon.GetClassName();

    maxRarity = ::Util.GetWeaponRarity(weapon.owner, prefix);
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
    string effect = ::Util.GetActiveWeaponEffect(weapon.owner, prefix);
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
        weapon.GetTag(), effectSlots, maxRarity, effect);
  }

  void CycleEffect() {
    SelectEffect((currentEffect + 1) % effects.size());
  }

  void SelectEffect(uint index) {
    if (effects.size() <= index) return;
    //if (index == currentEffect) return;

    if (currentEffect >= 0)
      weapon.owner.TakeInventory(effects[currentEffect], 1);
    currentEffect = index;
    currentEffectName = ::Util.GetEffectTitle(effects[currentEffect]);
    weapon.owner.GiveInventory(effects[currentEffect], 1);
  }

  void DiscardEffect(uint index) {
    DEBUG("DiscardEffect, total=%d, index=%d, current=%d",
        effects.size(), index, currentEffect);
    if (effects.size() <= index) return;
    if (index == currentEffect) {
      // The effect they want to discard is the current one.
      // Remove the effect now, then CycleEffect afterwards to select a new valid one.
      weapon.owner.TakeInventory(effects[index], 1);
      effects.Delete(index);
      CycleEffect();
    } else if (index < currentEffect) {
      // They want to discard an effect before the current one, which will result
      // in later effects being renumbered.
      currentEffect--;
    effects.Delete(index);
    }
  }

  uint GetXPForLevel(uint level) const {
    uint XP = ::Settings.base_level_cost() * level;
    if (weapon.bMeleeWeapon) {
      XP *= ::Settings.level_cost_mul_for("melee");
    }
    if (weapon.bWimpy_Weapon) {
      XP *= ::Settings.level_cost_mul_for("wimpy");
    }
    // For some reason it can't resolve bExplosive and bBFG
    // if (weapon.bExplosive) {
    //   XP *= ::Settings.level_cost_mul_for("explosive");
    // }
    // if (weapon.bBFG) {
    //   XP *= ::Settings.level_cost_mul_for("bfg");
    // }
    return XP;
  }

  bool AddXP(int newXP) {
    XP += newXP;
    if (XP >= maxXP) {
      LevelUp();
      return true;
    }
    return false;
  }

  // TODO: if the player rejects a level-up, reset the weapon to its previous
  // level.
  void LevelUp() {
    ++level;
    console.printf("Your %s is now level %d!", weapon.GetTag(), level);
    // TODO: leave the XP bar filled until the giver is done working. This is
    // harder than it looks because the giver may take several tics to do its thing.
    XP = XP - maxXP;
    maxXP = GetXPForLevel(level+1);
    weapon.owner.A_SetBlend("00 80 FF", 0.8, 40);
    // TODO: upgrades that modify the weapon's base stats should be activated here,
    // in some kind of ApplyUpgradesToWeapon() call.
    let giver = ::WeaponUpgradeGiver(weapon.owner.GiveInventoryType("::WeaponUpgradeGiver"));
    giver.wielded = self;
  }
}


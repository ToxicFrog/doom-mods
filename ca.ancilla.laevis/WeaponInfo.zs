// Info about a single weapon. These are held by the PerPlayerStats and each
// one records information about one of the player's weapons.
// It's also responsible for handling weapon level-ups.

class TFLV_WeaponInfo : Object play {
  // At the moment "weapon" is used both as a convenient way to remember a reference
  // to the weapon itself, and as the key for the info lookup when the caller has
  // a weapon but not the WeaponInfo.
  // TODO: implement a mode where the ClassName of the weapon is used as the key
  // instead, and PruneStaleInfo/GetInfoFor will leave the WeaponInfo intact if
  // the weapon is removed and rebind it to a new weapon of that type if one is
  // picked up. This would likely have weird interactions with mods where you can
  // drop weapons and pick up new weapons of the same class but with different
  // behaviour, like LD and DRLA, but would also enable War of Attrition-style
  // pistol start runs.
  Weapon weapon;
  string weaponType;
  TFLV_UpgradeBag upgrades;
  uint XP;
  uint maxXP;
  uint level;

  // Legendoom integration fields.
  uint effectSlots;
  uint maxRarity;
  bool canReplaceEffects;
  array<string> effects;
  int currentEffect;
  string currentEffectName;

  void Init(Actor weapon_) {
    weapon = Weapon(weapon_);
    weaponType = weapon.GetClassName();
    upgrades = new("TFLV_UpgradeBag");
    // XP = 0;
    // level = 0;
    maxXP = GetXPForLevel(level+1);
    // console.printf("WeaponInfo initialize, class=%s level=%d xp=%d/%d",
    //   weaponType, level, XP, maxXP);

    string LDWeaponType = "LDWeapon";
    currentEffect = -1;
    currentEffectName = "";
    effects.Clear();
    if (weapon is LDWeaponType) {
      InitLegendoom();
    } else {
      effectSlots = 0;
    }
  }

  bool GunRarityMatchesSetting(TFLV_WhichGuns setting, TFLV_LD_Rarity rarity) {
    if (rarity == RARITY_MUNDANE) {
      return setting & 1;
    } else {
      return setting & 2;
    }
  }

  void InitLegendoom() {
    string prefix = weapon.GetClassName();

    maxRarity = TFLV_Util.GetWeaponRarity(weapon.owner, prefix);
    canReplaceEffects = GunRarityMatchesSetting(TFLV_Settings.which_guns_can_replace(), maxRarity);
    if (GunRarityMatchesSetting(TFLV_Settings.which_guns_can_learn(), maxRarity)) {
      effectSlots = TFLV_Settings.base_ld_effect_slots()
        + maxRarity * TFLV_Settings.bonus_ld_effect_slots();
    } else {
      effectSlots = 0;
    }
    if (TFLV_Settings.ignore_gun_rarity()) {
      maxRarity = RARITY_EPIC;
    } else {
      maxRarity = max(RARITY_COMMON, maxRarity);
    }

    // And they start with an effect, so we should record that.
    string effect = TFLV_Util.GetActiveWeaponEffect(weapon.owner, prefix);
    if (effect != "") {
      currentEffect = 0;
      currentEffectName = TFLV_Util.GetEffectTitle(effect);
      effects.push(effect);
    }
    // console.printf("%s: effects=%d, rarity=%d, effect=%s",
    //   weapon.GetTag(), effectSlots, maxRarity, effect);
  }

  void CycleEffect() {
    //if (effects.size() <= 1) return;

    SelectEffect((currentEffect + 1) % effects.size());
  }

  void SelectEffect(uint index) {
    if (effects.size() <= index) return;
    //if (index == currentEffect) return;

    if (currentEffect >= 0)
      weapon.owner.TakeInventory(effects[currentEffect], 1);
    currentEffect = index;
    currentEffectName = TFLV_Util.GetEffectTitle(effects[currentEffect]);
    weapon.owner.GiveInventory(effects[currentEffect], 1);
  }

  void DiscardEffect(uint index) {
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
    uint XP = TFLV_Settings.base_level_cost() * level;
    if (weapon.bMeleeWeapon) {
      XP *= TFLV_Settings.level_cost_mul_for("melee");
    }
    if (weapon.bWimpy_Weapon) {
      XP *= TFLV_Settings.level_cost_mul_for("wimpy");
    }
    // For some reason it can't resolve bExplosive and bBFG
    // if (weapon.bExplosive) {
    //   XP *= TFLV_Settings.level_cost_mul_for("explosive");
    // }
    // if (weapon.bBFG) {
    //   XP *= TFLV_Settings.level_cost_mul_for("bfg");
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

  void LevelUp() {
    ++level;
    console.printf("Your %s is now level %d!", weapon.GetTag(), level);
    XP = XP - maxXP;
    maxXP = GetXPForLevel(level+1);
    weapon.owner.A_SetBlend("00 80 FF", 0.8, 40);
    // TODO: randomly generate a set of appropriate upgrades and have the player choose.
    // TODO: upgrades that modify the weapon's base stats should be activated here,
    // in some kind of ApplyUpgradesToWeapon() call.
    // upgrades.Add("TFLV_Upgrade_DirectDamage");
    upgrades.Add("TFLV_Upgrade_Homingshots");
  }
}


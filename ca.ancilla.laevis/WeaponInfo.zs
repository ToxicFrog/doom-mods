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
    XP = 0;
    level = 0;
    maxXP = GetXPForLevel(1);

    if (weapon is "LDWeapon") {
      InitLegendoom();
    } else {
      effectSlots = 0;
      currentEffect = -1;
    }
  }

  void InitLegendoom() {
    string prefix = weapon.GetClassName();
    if (!weapon.owner.FindInventory(prefix.."EffectActive")) {
      // Mundane weapons can be upgraded in-place to have a single common effect
      // but cannot replace learned effects.
      effectSlots = 1;
      currentEffect = -1;
      maxRarity = RARITY_COMMON;
      canReplaceEffects = false;
      console.printf("%s: effects=1, rarity=0, no effect", weapon.GetTag());
      return;
    }
    // For other weapons it depends on their rarity.
    maxRarity = TFLV_Util.GetWeaponRarity(weapon.owner, prefix);
    switch (maxRarity) {
      case RARITY_EPIC: effectSlots = 5; break;
      case RARITY_RARE: effectSlots = 4; break;
      case RARITY_UNCOMMON: effectSlots = 3; break;
      case RARITY_COMMON: effectSlots = 2; break;
      default: effectSlots = 0; break;
    }
    // They can all unlearn and replace effects, though.
    canReplaceEffects = true;
    // And they start with an effect, so we should record that.
    string effect = TFLV_Util.GetActiveWeaponEffect(weapon.owner, prefix);
    currentEffect = 0;
    currentEffectName = TFLV_Util.GetEffectTitle(effect);
    effects.push(effect);
    console.printf("%s: effects=%d, rarity=%d, effect=%s",
      weapon.GetTag(), effectSlots, maxRarity, effect);
  }

  void CycleEffect() {
    if (effects.size() <= 1) return;

    SelectEffect((currentEffect + 1) % effects.size());
  }

  void SelectEffect(uint index) {
    if (effects.size() <= index) return;
    if (index == currentEffect) return;

    if (currentEffect >= 0)
      weapon.owner.TakeInventory(effects[currentEffect], 1);
    currentEffect = index;
    currentEffectName = TFLV_Util.GetEffectTitle(effects[currentEffect]);
    weapon.owner.GiveInventory(effects[currentEffect], 1);
  }

  double GetDamageBonus() const {
    return 1 + level * TFLV_Settings.gun_damage_bonus();
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
  }
}


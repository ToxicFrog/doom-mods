// Info about a single weapon. These are held by the PerPlayerStats and each
// one records information about one of the player's weapons.
// It's also responsible for handling weapon level-ups.

// TODO: move these constants into cvars and expose them in a configuration
// menu, here and in PerPlayerStats.
// How much extra damage a weapon does per level. Stacks additively with itself
// and multiplicatively with DAMAGE_BONUS_PER_PLAYER_LEVEL.
const DAMAGE_BONUS_PER_WEAPON_LEVEL = 0.05;
// Base XP needed to go from level 0 to level 1.
// This is currently scaled such that completely clearing MAP01 on UV will let
// you level one weapon from 0 to 1.
// MAP01 of Sunder (a slaughterwad) will let you do that 27 times, or level up
// a single weapon to level 5.
const BASE_XP_FOR_WEAPON_LEVEL = 1200;
// Level-up cost multipliers for melee weapons, puny weapons, explosive weapons,
// and the BFG. These stack!
const LEVEL_COST_MULTIPLIER_FOR_MELEE = 0.5;
const LEVEL_COST_MULTIPLIER_FOR_WIMPY = 0.5;
const LEVEL_COST_MULTIPLIER_FOR_EXPLOSIVE = 2.0;
const LEVEL_COST_MULTIPLIER_FOR_BFG = 2.0;

class TFLV_WeaponInfo : Object play {
  Weapon weapon;
  uint XP;
  uint maxXP;
  uint level;

  // Legendoom integration fields.
  uint abilitySlots;
  uint maxRarity;
  bool canReplaceAbilities;
  array<string> abilities;

  void Init(Actor weapon_) {
    weapon = Weapon(weapon_);
    XP = 0;
    level = 0;
    maxXP = GetXPForLevel(1);

    if (weapon is "LDWeapon") {
      InitLegendoom();
    } else {
      abilitySlots = 0;
    }
  }

  void InitLegendoom() {
    string prefix = weapon.GetClassName();
    if (!weapon.owner.FindInventory(prefix.."EffectActive")) {
      // Mundane weapons can be upgraded in-place to have a single common ability
      // but cannot replace learned abilities.
      abilitySlots = 1;
      maxRarity = RARITY_COMMON;
      canReplaceAbilities = false;
      console.printf("%s: abilities=1, rarity=0, no ability", weapon.GetTag());
      return;
    }
    // For other weapons it depends on their rarity.
    maxRarity = TFLV_Util.GetWeaponRarity(weapon.owner, prefix);
    switch (maxRarity) {
      case RARITY_EPIC: abilitySlots = 5; break;
      case RARITY_RARE: abilitySlots = 4; break;
      case RARITY_UNCOMMON: abilitySlots = 3; break;
      case RARITY_COMMON: abilitySlots = 2; break;
      default: abilitySlots = 0; break;
    }
    // They can all unlearn and replace abilities, though.
    canReplaceAbilities = true;
    // And they start with an ability, so we should record that.
    string ability = TFLV_Util.GetWeaponEffectName(weapon.owner, prefix);
    console.printf("%s: abilities=%d, rarity=%d, ability=%s",
      weapon.GetTag(), abilitySlots, maxRarity, ability);
    abilities.push(ability);
  }

  double GetDamageBonus() const {
    return 1 + level * DAMAGE_BONUS_PER_WEAPON_LEVEL;
  }

  uint GetXPForLevel(uint level) const {
    uint XP = BASE_XP_FOR_WEAPON_LEVEL * level;
    if (weapon.bMeleeWeapon) {
      XP *= LEVEL_COST_MULTIPLIER_FOR_MELEE;
    }
    if (weapon.bWimpy_Weapon) {
      XP *= LEVEL_COST_MULTIPLIER_FOR_WIMPY;
    }
    // For some reason it can't resolve bExplosive and bBFG
    // if (weapon.bExplosive) {
    //   XP *= LEVEL_COST_MULTIPLIER_FOR_EXPLOSIVE;
    // }
    // if (weapon.bBFG) {
    //   XP *= LEVEL_COST_MULTIPLIER_FOR_BFG;
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
    weapon.damageMultiply = 1 + level * DAMAGE_BONUS_PER_WEAPON_LEVEL;
    // console.printf("Gun DamageMultiply is now %f", weapon.DamageMultiply);
  }
}


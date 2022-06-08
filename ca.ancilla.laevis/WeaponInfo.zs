// Info about a single weapon. These are held by the PerPlayerStats and each
// one records information about one of the player's weapons.
// It's also responsible for handling weapon level-ups.

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

  void Init(Actor weapon_) {
    weapon = Weapon(weapon_);
    XP = 0;
    level = 0;
    maxXP = XPForLevel(1);
  }

  double DamageBonus() const {
    return 1 + level * DAMAGE_BONUS_PER_WEAPON_LEVEL;
  }

  uint XPForLevel(uint level) const {
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
    maxXP = XPForLevel(level+1);
    weapon.owner.A_SetBlend("00 80 FF", 0.8, 40);
    weapon.damageMultiply = 1 + level * DAMAGE_BONUS_PER_WEAPON_LEVEL;
    // console.printf("Gun DamageMultiply is now %f", weapon.DamageMultiply);
  }
}


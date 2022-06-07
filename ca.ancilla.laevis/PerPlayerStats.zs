// Stats object. Each player gets one of these in their inventory.
// Holds information about the player's guns and the player themself.
// Also handles applying some damage/resistance bonuses using ModifyDamage().

// How many times the player needs to level up their guns before they get an
// intrinsic stat bonus.
const GUN_LEVELS_PER_PLAYER_LEVEL = 2;
// How much extra damage they do per player level. Additive; if this is 0.05
// and the player is level 20 they do double damage.
const DAMAGE_BONUS_PER_PLAYER_LEVEL = 0.05;
// How much incoming damage is reduced by. Multiplicative, so no matter what
// it's set to it won't ever let the player become completely invincible. If
// this is 0.05 and the player is level 20, they take 36% damage.
const DAMAGE_REDUCTION_PER_PLAYER_LEVEL = 0.05;

class TFLV_PerPlayerStats : Force {
  array<TFLV_WeaponInfo> weapons;
  uint XP;
  uint level;

  // Returns the info structure for the given weapon. If none exists, allocates
  // and initializes a new one and returns that.
  TFLV_WeaponInfo GetInfoFor(Actor weapon) {
    for (int i = 0; i < weapons.size(); ++i) {
      if (weapons[i].weapon == weapon) {
        return weapons[i];
      }
    }
    // Didn't find one, so create a new one.
    TFLV_WeaponInfo info = new("TFLV_WeaponInfo");
    info.Init(weapon);
    weapons.push(info);
    return info;
  }

  // Delete WeaponInfo entries for weapons that don't exist anymore.
  // Called as a housekeeping task whenever a weapon levels up.
  // Depending on whether the game being played permits dropping/destroying/upgrading
  // weapons, this might be a no-op.
  void PruneStaleInfo() {
    for (int i = weapons.size() - 1; i >= 0; --i) {
      if (!weapons[i].weapon) {
        weapons.Delete(i);
      }
    }
  }

  // Add XP to a weapon. If the weapon leveled up, also do some housekeeping
  // and possibly level up the player as well.
  // TODO: scale XP nonlinearly based on how dangerous the target is, so (e.g.)
  // a Cyberdemon is worth more XP per point of damage than a Former.
  void AddXPTo(Actor weapon, int damage) {
    TFLV_WeaponInfo info = GetInfoFor(weapon);
    if (info.AddXP(damage)) {
      // Weapon leveled up!
      PruneStaleInfo();
      // Also give the player some XP.
      // TODO: player levels up based on number of weapon levels gained, similar
      // to War of Attrition. Investigate whether it makes more sense to level up
      // based on XP.
      ++XP;
      if (XP >= GUN_LEVELS_PER_PLAYER_LEVEL) {
        XP -= GUN_LEVELS_PER_PLAYER_LEVEL;
        ++level;
        console.printf("You are now level %d!", level);
        Weapon(weapon).owner.A_SetBlend("FF FF FF", 0.8, 40);
      }
    }
  }

  void PrintXPFor(Actor weapon) {
    TFLV_WeaponInfo info = GetInfoFor(weapon);
    console.printf("Gun %s is level %d and has %d/%d XP.",
      info.weapon.GetTag(), info.level, info.XP, info.maxXP);
  }

  // Apply player level-up bonuses whenever the player deals or receives damage.
  // This is also where bonuses to individual weapon damage are applied.
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (damage <= 0) {
      return;
    }
    if (passive) {
      newdamage = damage * (1 - DAMAGE_REDUCTION_PER_PLAYER_LEVEL) ** level;
      console.printf("%d incoming damage reduced to %d", damage, newdamage);
    } else {
      TFLV_WeaponInfo info = GetInfoFor(owner.player.ReadyWeapon);
      newdamage = damage
        * (1 + DAMAGE_BONUS_PER_PLAYER_LEVEL * level)
        * owner.player.ReadyWeapon.DamageMultiply;
      console.printf("%d outgoing damage increased to %d", damage, newdamage);
    }
  }
}


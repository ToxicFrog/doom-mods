// Stats object. Each player gets one of these in their inventory.
// Holds information about the player's guns and the player themself.
// Also handles applying some damage/resistance bonuses using ModifyDamage().

// How many times the player needs to level up their guns before they get an
// intrinsic stat bonus.
const GUN_LEVELS_PER_PLAYER_LEVEL = 10;
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
  void AddXPTo(Actor weapon, int xp) {
    TFLV_WeaponInfo info = GetInfoFor(weapon);
    if (info.AddXP(xp)) {
      // Weapon leveled up!
      PruneStaleInfo();
      // Also give the player some XP.
      // console.printf("XP=%d, XPperLevel=%d", XP, GUN_LEVELS_PER_PLAYER_LEVEL);
      ++self.XP;
      // console.printf("XP=%d, XPperLevel=%d", XP, GUN_LEVELS_PER_PLAYER_LEVEL);
      if (self.XP >= GUN_LEVELS_PER_PLAYER_LEVEL) {
        self.XP -= GUN_LEVELS_PER_PLAYER_LEVEL;
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

  // Return XP bar info as [player XP, max XP, weapon XP, max XP], using
  // the current weapon.
  uint, uint, uint, uint XPBarInfo() const {
    TFLV_WeaponInfo info = GetInfoFor(owner.player.ReadyWeapon);
    return
      XP, GUN_LEVELS_PER_PLAYER_LEVEL,
      info.XP, info.maxXP;
  }

  uint XPForDamage(Actor target, uint damage) const {
    uint xp = damage;
    if (target.health < 0) {
      // Can't get more XP than the target has hitpoints.
      xp = xp + target.health;
    }
    if (target.GetSpawnHealth() > 100) {
      // Enemies with lots of HP get a log-scale XP bonus.
      // This works out to about a 1.8x bonus for Archviles and a 2.6x bonus
      // for the Cyberdemon.
      xp = xp * (log10(target.GetSpawnHealth()) - 1);
    }
    return xp;
  }

  uint TotalDamage(Weapon wielded, uint damage) const {
    TFLV_WeaponInfo info = GetInfoFor(wielded);
    return damage
      * (1 + DAMAGE_BONUS_PER_PLAYER_LEVEL * level)
      * info.DamageBonus();
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
      // Incoming damage. Apply damage reduction.
      newdamage = damage * (1 - DAMAGE_REDUCTION_PER_PLAYER_LEVEL) ** level;
      console.printf("%d incoming damage reduced to %d", damage, newdamage);
    } else {
      // Outgoing damage. 'source' is the *target* of the damage.
      let target = source;
      if (!target.bIsMonster) {
        // Damage bonuses and XP assignment apply only when attacking monsters,
        // not decorations or yourself.
        newdamage = damage;
        return;
      }

      Weapon wielded = owner.player.ReadyWeapon;
      newdamage = TotalDamage(wielded, damage);

      uint xp = XPForDamage(target, damage);
      AddXPTo(wielded, xp);

      console.printf("%d outgoing damage increased to %d; got %d XP", damage, newdamage, xp);
    }
  }
}


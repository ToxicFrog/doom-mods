// Stats object. Each player gets one of these in their inventory.
// Holds information about the player's guns and the player themself.
// Also handles applying some damage/resistance bonuses using ModifyDamage().

// How many times the player needs to level up their guns before they get an
// intrinsic stat bonus.
const GUN_LEVELS_PER_PLAYER_LEVEL = 10;
// How much extra damage they do per player level. Additive; if this is 0.05
// and the player is level 20 they do double damage.
const DAMAGE_BONUS_PER_PLAYER_LEVEL = 0.05;
// Incoming damage is multiplied by this raised to the player-level power.
// Unlike outgoing damage this has diminishing returns, so the player will never
// become truly invincible.
// If set to 0.95, it works out to ~36% damage taken by level 20.
const DEFENCE_BONUS_PER_PLAYER_LEVEL = 0.95;

// Used to get all the information needed for the UI.
struct TFLV_CurrentStats {
  // Player stats.
  uint pxp;
  uint pmax;
  uint plvl;
  double pdmg;
  double pdef;
  // Stats for current weapon.
  uint wxp;
  uint wmax;
  uint wlvl;
  double wdmg;
  // Name of current weapon.
  string wname;
  // Currently active weapon effect.
  string effect;
}

class TFLV_PerPlayerStats : TFLV_Force {
  array<TFLV_WeaponInfo> weapons;
  uint XP;
  uint level;
  bool legendoomInstalled;

  // TODO: if the player has a normal gun, and picks up a Legendoom gun of the
  // same kind, their gun gets upgraded in-place and the existing info struct
  // remains, which means it will now count as a mundane weapon that earned an
  // LD effect and not as a (more powerful) LD weapon. We need to detect that
  // occurrence, possibly in HandlePickup, and invalidate the existing info
  // struct for it.

  // Fill in a CurrentStats struct with the current state of the player & their
  // currently wielded weapon. This should contain all the information needed
  // to draw the UI.
  void GetCurrentStats(out TFLV_CurrentStats stats) const {
    stats.pxp = XP;
    stats.pmax = GUN_LEVELS_PER_PLAYER_LEVEL;
    stats.plvl = level;
    stats.pdmg = 1 + level * DAMAGE_BONUS_PER_PLAYER_LEVEL;
    stats.pdef = DEFENCE_BONUS_PER_PLAYER_LEVEL ** level;

    TFLV_WeaponInfo info = GetInfoForCurrentWeapon();
    if (info) {
      stats.wxp = info.XP;
      stats.wmax = info.maxXP;
      stats.wlvl = info.level;
      stats.wdmg = info.GetDamageBonus();
      stats.wname = info.weapon.GetTag();
      stats.effect = info.currentEffectName;
    } else {
      stats.wxp = 0;
      stats.wmax = 0;
      stats.wlvl = 0;
      stats.wdmg = 0.0;
      stats.wname = "(no weapon)";
      stats.effect = "";
    }
  }

  // Return the WeaponInfo for the currently readied weapon. If the player
  // does not have a weapon ready, return null.
  TFLV_WeaponInfo GetInfoForCurrentWeapon() const {
    Weapon wielded = owner.player.ReadyWeapon;
    if (wielded) {
      // WTF why is this allowed? TODO fix this to not rely on violating security boundaries
      return GetInfoFor(wielded);
    } else {
      return null;
    }
  }

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
  void AddXPTo(Actor weapon, int xp) {
    TFLV_WeaponInfo info = GetInfoFor(weapon);
    if (info.AddXP(xp)) {
      // Weapon leveled up!
      if (legendoomInstalled) {
        let ldGiver = TFLV_LegendoomEffectGiver(owner.GiveInventoryType("TFLV_LegendoomEffectGiver"));
        ldGiver.wielded = GetInfoForCurrentWeapon();
        ldGiver.SetStateLabel("LDLevelUp");
      }

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

      // Do some cleanup.
      PruneStaleInfo();
    }
  }

  uint GetXPForDamage(Actor target, uint damage) const {
    uint xp = min(damage, target.health);
    if (target.GetSpawnHealth() > 100) {
      // Enemies with lots of HP get a log-scale XP bonus.
      // This works out to about a 1.8x bonus for Archviles and a 2.6x bonus
      // for the Cyberdemon.
      xp = xp * (log10(target.GetSpawnHealth()) - 1);
    }
    return xp;
  }

  uint GetTotalDamage(Weapon wielded, uint damage) const {
    TFLV_WeaponInfo info = GetInfoFor(wielded);
    return damage
      * (1 + DAMAGE_BONUS_PER_PLAYER_LEVEL * level)
      * info.GetDamageBonus();
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
      newdamage = damage * (DEFENCE_BONUS_PER_PLAYER_LEVEL ** level);
      // console.printf("%d incoming damage reduced to %d", damage, newdamage);
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
      newdamage = GetTotalDamage(wielded, damage);

      uint xp = GetXPForDamage(target, damage);
      AddXPTo(wielded, xp);

      // console.printf("%d outgoing damage increased to %d; got %d XP", damage, newdamage, xp);
    }
  }
}


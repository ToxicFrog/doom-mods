// Stats object. Each player gets one of these in their inventory.
// Holds information about the player's guns and the player themself.
// Also handles applying some damage/resistance bonuses using ModifyDamage().

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
  TFLV_WeaponInfo infoForCurrentWeapon;
  int prevScore;

  // HACK HACK HACK
  // The LaevisLevelUpScreen needs to be able to get a handle to the specific
  // EffectGiver associated with that menu, so it puts itself into this field
  // just before opening the menu and clears it afterwards.
  TFLV_LegendoomEffectGiver currentEffectGiver;

  clearscope static TFLV_PerPlayerStats GetStatsFor(PlayerPawn pawn) {
    return TFLV_PerPlayerStats(pawn.FindInventory("TFLV_PerPlayerStats"));
  }

  // Special pickup handling so that if the player picks up an LD legendary weapon
  // that upgrades their mundane weapon in-place, we handle this correctly rather
  // than thinking it's a mundane weapon that earned an LD effect through leveling
  // up.
  override bool HandlePickup(Inventory item) {
    // Workaround for zscript `is` operator being weird.
    string LDWeaponNameAlternationType = "LDWeaponNameAlternation";
    string LDPermanentInventoryType = "LDPermanentInventory";
    if (item is LDWeaponNameAlternationType) return super.HandlePickup(item);
    if (!(item is LDPermanentInventoryType)) return super.HandlePickup(item);

    string cls = item.GetClassName();
    if (cls.IndexOf("EffectActive") < 0) return super.HandlePickup(item);

    // If this is flagged as "notelefrag", it means it was produced by the level-
    // up code and should upgrade our current item in place rather than invalidating
    // its info block.
    if (item.bNOTELEFRAG) return super.HandlePickup(item);

    // At this point we know that the pickup is a Legendoom weapon effect token
    // and it's not one we created. So we need to figure out if the player has
    // an existing entry for a mundane weapon of the same type and clear it if so.
    cls = cls.Left(cls.IndexOf("EffectActive"));
    for (int i = 0; i < weapons.size(); ++i) {
      if (weapons[i].weapon is cls) {
        weapons[i].weapon = null;
      }
    }
    return super.HandlePickup(item);
  }

  // Fill in a CurrentStats struct with the current state of the player & their
  // currently wielded weapon. This should contain all the information needed
  // to draw the UI.
  // Returns true if it was able to get all the necessary weapon information,
  // false otherwise.
  bool GetCurrentStats(out TFLV_CurrentStats stats) const {
    stats.pxp = XP;
    stats.pmax = TFLV_Settings.gun_levels_per_player_level();
    stats.plvl = level;
    stats.pdmg = 1 + level * TFLV_Settings.player_damage_bonus();
    stats.pdef = TFLV_Settings.player_defence_bonus() ** level;

    TFLV_WeaponInfo info = GetInfoForCurrentWeapon();
    if (info) {
      stats.wxp = info.XP;
      stats.wmax = info.maxXP;
      stats.wlvl = info.level;
      stats.wdmg = info.GetDamageBonus();
      stats.wname = info.weapon.GetTag();
      stats.effect = info.currentEffectName;
      return true;
    } else {
      stats.wxp = 0;
      stats.wmax = 0;
      stats.wlvl = 0;
      stats.wdmg = 0.0;
      stats.wname = "(no weapon)";
      stats.effect = "";
      return false;
    }
  }

  // TODO: API here is a bit of a dog's breakfast, with GetInfoFor/GetOrCreateInfoFor,
  // TryGetInfoFor, etc. I think the only externally called ones are GetInfoForCurrentWeapon()
  // (called by ui code) and GetOrCreateInfoForCurrentWeapon() (called by playsim code).
  // This should be cleaned up a lot, especially since the Poll state now means we
  // are guaranteed to have info for the current weapon within one tic of it being
  // selected.

  // Return the WeaponInfo for the currently readied weapon. If the player
  // does not have a weapon ready, return null.
  TFLV_WeaponInfo GetInfoForCurrentWeapon() const {
    Weapon wielded = owner.player.ReadyWeapon;
    if (!wielded) {
      return null;
    } else if (infoForCurrentWeapon && wielded == infoForCurrentWeapon.weapon) {
      // The 99% case is that the player has the same weapon equipped this frame
      // that they did last frame.
      return infoForCurrentWeapon;
    } else {
      return TryGetInfoFor(wielded);
    }
  }

  TFLV_WeaponInfo TryGetInfoFor(Actor weapon) const {
    for (int i = 0; i < weapons.size(); ++i) {
      if (weapons[i].weapon == weapon) {
        return weapons[i];
      }
    }
    return null;
  }

  // Like GetInfoForCurrentWeapon, but if WeaponInfo doesn't exist for the current
  // weapon it will allocate a new one. As such this is not safe to call from
  // UI code.
  TFLV_WeaponInfo GetOrCreateInfoForCurrentWeapon() {
    Weapon wielded = owner.player.ReadyWeapon;
    if (!wielded) {
      return null;
    } else if (infoForCurrentWeapon && wielded == infoForCurrentWeapon.weapon) {
      // The 99% case is that the player has the same weapon equipped this frame
      // that they did last frame.
      return infoForCurrentWeapon;
    } else {
      infoForCurrentWeapon = GetInfoFor(wielded);
      return infoForCurrentWeapon;
    }
  }

  // Returns the info structure for the given weapon. If none exists, allocates
  // and initializes a new one and returns that.
  TFLV_WeaponInfo GetInfoFor(Actor weapon) {
    TFLV_WeaponInfo info = TryGetInfoFor(weapon);
    if (info) return info;

    // Didn't find one, so create a new one.
    info = new("TFLV_WeaponInfo");
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
  void AddXP(int xp) {
    TFLV_WeaponInfo info = GetOrCreateInfoForCurrentWeapon();
    if (info.AddXP(xp)) {
      // Weapon leveled up!
      if (legendoomInstalled && (info.level % TFLV_Settings.gun_levels_per_ld_effect()) == 0) {
        let ldGiver = TFLV_LegendoomEffectGiver(owner.GiveInventoryType("TFLV_LegendoomEffectGiver"));
        ldGiver.wielded = GetInfoForCurrentWeapon();
        ldGiver.SetStateLabel("LDLevelUp");
      }

      // Also give the player some XP.
      // console.printf("XP=%d, XPperLevel=%d", XP, GUN_LEVELS_PER_PLAYER_LEVEL);
      ++self.XP;
      // console.printf("XP=%d, XPperLevel=%d", XP, GUN_LEVELS_PER_PLAYER_LEVEL);
      if (self.XP >= TFLV_Settings.gun_levels_per_player_level()) {
        self.XP -= TFLV_Settings.gun_levels_per_player_level();
        ++level;
        console.printf("You are now level %d!", level);
        owner.A_SetBlend("FF FF FF", 0.8, 40);
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

  uint GetTotalDamage(TFLV_WeaponInfo info, uint damage) const {
    return damage
      * (1 + TFLV_Settings.player_damage_bonus() * level)
      * info.GetDamageBonus();
  }

  // Apply player level-up bonuses whenever the player deals or receives damage.
  // This is also where bonuses to individual weapon damage are applied.
  // TODO: alternate mode where the player's score (from e.g. lazypoints) is used
  // as the XP source, rather than calculating it ourself.
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (damage <= 0) {
      return;
    }
    if (passive) {
      // Incoming damage. Apply damage reduction.
      newdamage = damage * (TFLV_Settings.player_defence_bonus() ** level);
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

      newdamage = GetTotalDamage(GetInfoForCurrentWeapon(), damage);

      if (!TFLV_Settings.use_score_for_xp()) {
        AddXP(GetXPForDamage(target, damage));
      }
    }
  }

  void Initialize() {
    prevScore = -1;
  }

  // Runs once per tic.
  void TickStats() {
    // This ensures that the currently wielded weapon always has a WeaponInfo
    // struct associated with it. It should be pretty fast.
    let info = GetOrCreateInfoForCurrentWeapon();

    // No score integration? Nothing else to do.
    if (!TFLV_Settings.use_score_for_xp()) {
      prevScore = -1;
      return;
    }

    // Otherwise, assign XP based on score.
    if (prevScore < 0) {
      // Negative score means score-to-XP mode was just turned on and should
      // be initialized.
      prevScore = owner.score;
      return;
    } else if (owner.score > prevScore) {
      AddXP(owner.score - prevScore);
      prevScore = owner.score;
    }
  }

  States {
    Spawn:
      TNT1 A 0 Initialize();
    Poll:
      TNT1 A 1 TickStats();
      LOOP;
  }
}


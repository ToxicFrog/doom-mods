// Stats object. Each player gets one of these in their inventory.
// Holds information about the player's guns and the player themself.
// Also handles applying some damage/resistance bonuses using ModifyDamage().
#namespace TFLV;
#debug off

// Used to get all the information needed for the UI.
struct ::CurrentStats {
  // Player stats.
  ::Upgrade::UpgradeBag pupgrades;
  uint pxp;
  uint pmax;
  uint plvl;
  // Stats for current weapon.
  ::WeaponInfo winfo;
  ::Upgrade::UpgradeBag wupgrades;
  uint wxp;
  uint wmax;
  uint wlvl;
  // Name of current weapon.
  string wname;
  // Currently active weapon effect.
  string effect;
}

// TODO: see if there's a way we can evacuate this to the StaticEventHandler
// and reinsert it into the player when something happens, so that it reliably
// persists across deaths, pistol starts, etc -- make this an option.
class ::PerPlayerStats : ::Force {
  array<::WeaponInfo> weapons;
  ::Upgrade::UpgradeBag upgrades;
  uint XP;
  uint level;
  bool legendoomInstalled;
  ::WeaponInfo infoForCurrentWeapon;
  int prevScore;

  // HACK HACK HACK
  // The various level up menus need to be able to get a handle to the specific
  // UpgradeGiver associated with that menu, so it puts itself into this field
  // just before opening the menu and clears it afterwards.
  // This is also used to check if an upgrade giver is currently awaiting a menu
  // response, in which case other upgrade givers will block (since it's possible
  // to have up to three upgrade givers going off at once).
  ::UpgradeGiver currentEffectGiver;

  clearscope static ::PerPlayerStats GetStatsFor(Actor pawn) {
    return ::PerPlayerStats(pawn.FindInventory("::PerPlayerStats"));
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
  // If it couldn't get the needed information, fills in nothing and returns false.
  // This is safe to call from UI context.
  bool GetCurrentStats(out ::CurrentStats stats) const {
    ::WeaponInfo info = GetInfoForCurrentWeapon();
    if (!info) return false;

    stats.pxp = XP;
    stats.pmax = ::Settings.gun_levels_per_player_level();
    stats.plvl = level;
    stats.pupgrades = upgrades;
    stats.winfo = info;
    stats.wxp = info.XP;
    stats.wmax = info.maxXP;
    stats.wlvl = info.level;
    stats.wname = info.weapon.GetTag();
    stats.wupgrades = info.upgrades;
    stats.effect = info.currentEffectName;
    return true;
  }

  // Return the WeaponInfo for the currently readied weapon. If the player
  // does not have a weapon ready, or if the weaponinfo for it hasn't yet been
  // created, return null.
  ::WeaponInfo GetInfoForCurrentWeapon() const {
    Weapon wielded = owner.player.ReadyWeapon;
    if (wielded && infoForCurrentWeapon && infoForCurrentWeapon.weapon == wielded) {
      return infoForCurrentWeapon;
    }
    return null;
  }

  // Like GetInfoForCurrentWeapon, but if WeaponInfo doesn't exist for the current
  // weapon it will try to find a compatible existing one to attach to it, or,
  // failing that, create a new one. As such this is not suitable for use from
  // ui scope.
  // If the player is not currently wielding a weapon, returns null.
  ::WeaponInfo GetOrCreateInfoForCurrentWeapon() {
    Weapon wielded = owner.player.ReadyWeapon;
    if (!wielded) return null;

    ::WeaponInfo info = GetInfoForCurrentWeapon();
    if (info) return info;

    // The player is wielding a weapon but it's not the weapon associated with
    // the current weapon info. Try to find an existing WeaponInfo associated
    // with this weapon.
    info = FindInfoFor(wielded);
    // Failing that, try to bind it to a compatible existing one.
    if (!info) info = BindExistingInfoTo(wielded);
    // If even that fails, create a new one ex nihilo.
    if (!info) {
      info = new("::WeaponInfo");
      info.Init(wielded);
      weapons.push(info);
    }

    infoForCurrentWeapon = info;
    return info;
  }

  ::WeaponInfo FindInfoFor(Weapon wpn) const {
    for (int i = 0; i < weapons.size(); ++i) {
      if (weapons[i].weapon == wpn) {
        return weapons[i];
      }
    }
    return null;
  }

  // Given a weapon, try to find a compatible existing unused WeaponInfo we can
  // attach to it.
  ::WeaponInfo BindExistingInfoTo(Weapon wpn) {
    TFLV_UpgradeBindingMode mode = ::Settings.upgrade_binding_mode();

    // Can't rebind WeaponInfo in BIND_WEAPON mode.
    if (mode == TFLV_BIND_WEAPON) return null;

    ::WeaponInfo maybe_info = null;
    for (int i = 0; i < weapons.size(); ++i) {
      // Can never rebind across different weapon classes.
      if (weapons[i].weaponType != wpn.GetClassName()) continue;
      if (mode == TFLV_BIND_CLASS) {
        // In class-bound mode, all weapons of the same type share the same WeaponInfo.
        // When you switch weapons, the WeaponInfo for that type gets rebound to the
        // newly wielded weapon.
        weapons[i].Rebind(wpn);
        return weapons[i];
      } else if (mode == TFLV_BIND_WEAPON_INHERITABLE) {
        // In inheritable weapon-bound mode, a weaponinfo is only reusable if (a)
        // the weapon it was bound to no longer exists, or (b) the weapon it was bound
        // to is no longer in our inventory. We prefer the latter, if both are options.
        if (!maybe_info || maybe_info.weapon && weapons[i].weapon == null) {
          maybe_info = weapons[i];
        }
      } else {
        ThrowAbortException("Unknown UpgradeBindingMode %d!", mode);
      }
    }
    if (maybe_info) {
      maybe_info.Rebind(wpn);
    }
    return maybe_info;
  }

  // Delete WeaponInfo entries for weapons that don't exist anymore.
  // Called as a housekeeping task whenever a weapon levels up.
  // Depending on whether the game being played permits dropping/destroying/upgrading
  // weapons, this might be a no-op.
  void PruneStaleInfo() {
    // Only do this in BIND_WEAPON mode. In other binding modes the WeaponInfos
    // can be rebound to new weapons.
    if (::Settings.upgrade_binding_mode() != TFLV_BIND_WEAPON) return;
    for (int i = weapons.size() - 1; i >= 0; --i) {
      if (!weapons[i].weapon) {
        weapons.Delete(i);
      }
    }
  }

  // Add XP to a weapon. If the weapon leveled up, also do some housekeeping
  // and possibly level up the player as well.
  void AddXP(int xp) {
    ::WeaponInfo info = GetOrCreateInfoForCurrentWeapon();
    if (!info) return;
    if (info.AddXP(xp)) {
      // Weapon leveled up!
      DEBUG("level up, level=%d, GLPE=%d",
        info.level, ::Settings.gun_levels_per_ld_effect());
      if (legendoomInstalled && (info.level % ::Settings.gun_levels_per_ld_effect()) == 0) {
        let ldGiver = ::LegendoomEffectGiver(owner.GiveInventoryType("::LegendoomEffectGiver"));
        ldGiver.wielded = GetInfoForCurrentWeapon();
      }

      // Also give the player some XP.
      ++self.XP;
      if (self.XP >= ::Settings.gun_levels_per_player_level()) {
        self.XP -= ::Settings.gun_levels_per_player_level();
        ++level;
        console.printf("You are now level %d!", level);
        owner.A_SetBlend("FF FF FF", 0.8, 40);
        let giver = ::PlayerUpgradeGiver(owner.GiveInventoryType("::PlayerUpgradeGiver"));
        giver.stats = self;
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

  // Handlers for events that player/gun upgrades may be interested in.
  // These are called from the EventManager on the corresponding world events,
  // and call the handlers on the upgrades in turn.
  // They ignore shots with the +INCOMBAT flag set; this is a Strife dialogue flag
  // repurposed here to mean "this actor was spawned by Laevis and should not trigger
  // upgrades", to prevent upgrade recursion, e.g. an "on hit spawn shrapnel" upgrade
  // causing more shrapnel to spawn whenever shrapnel hits something.
  void OnProjectileCreated(Actor shot) {
    if (shot.bINCOMBAT) return;
    upgrades.OnProjectileCreated(owner, shot);
    let info = GetOrCreateInfoForCurrentWeapon();
    if (info) info.upgrades.OnProjectileCreated(owner, shot);
  }

  void OnDamageDealt(Actor shot, Actor target, uint damage) {
    if (shot && shot.bINCOMBAT) return;
    upgrades.OnDamageDealt(owner, shot, target, damage);
    // Record whether it was a missile or a projectile, for the purposes of
    // deciding what kinds of upgrades to spawn.
    let info = GetOrCreateInfoForCurrentWeapon();
    if (!info) return;
    if (shot && shot.bMISSILE) {
      info.projectile_shots++;
    } else {
      info.hitscan_shots++;
    }
    info.upgrades.OnDamageDealt(owner, shot, target, damage);
  }

  void OnDamageReceived(Actor shot, Actor attacker, uint damage) {
    if (shot && shot.bINCOMBAT) return;
    upgrades.OnDamageReceived(owner, shot, attacker, damage);
    let info = GetOrCreateInfoForCurrentWeapon();
    if (!info) return;
    info.upgrades.OnDamageReceived(owner, shot, attacker, damage);
  }

  void OnKill(Actor shot, Actor target) {
    upgrades.OnKill(owner, shot, target);
    let info = GetOrCreateInfoForCurrentWeapon();
    if (!info) return;
    info.upgrades.OnKill(owner, shot, target);
  }

  // Apply player level-up bonuses whenever the player deals or receives damage.
  // This is also where bonuses to individual weapon damage are applied.
  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (damage <= 0) {
      return;
    }
    ::WeaponInfo info = GetOrCreateInfoForCurrentWeapon();
    if (passive) {
      // Incoming damage.
      DEBUG("MD(p): %s <- %s <- %s (%d/%s) flags=%X",
        ::Util.SafeCls(owner), ::Util.SafeCls(inflictor), ::Util.SafeCls(source),
        damage, damageType, flags);

      // TODO: this (and ModifyDamageDealt below) should take into account the
      // difference between current and original damage
      double tmpdamage = upgrades.ModifyDamageReceived(owner, inflictor, source, damage);
      if (info)
        tmpdamage = info.upgrades.ModifyDamageReceived(owner, inflictor, source, tmpdamage);
      newdamage = tmpdamage;
    } else {
      DEBUG("MD: %s -> %s -> %s (%d/%s) flags=%X",
        ::Util.SafeCls(owner), ::Util.SafeCls(inflictor), ::Util.SafeCls(source),
        damage, damageType, flags);
      // Outgoing damage. 'source' is the *target* of the damage.
      let target = source;
      if (!target.bIsMonster) {
        // Damage bonuses and XP assignment apply only when attacking monsters,
        // not decorations or yourself.
        newdamage = damage;
        return;
      }

      // XP is based on base damage, not final damage.
      if (!::Settings.use_score_for_xp()) {
        AddXP(GetXPForDamage(target, damage));
      }

      if (!inflictor || !inflictor.bINCOMBAT) {
        double tmpdamage = upgrades.ModifyDamageDealt(owner, inflictor, source, damage);
        if (info)
          tmpdamage = info.upgrades.ModifyDamageDealt(owner, inflictor, source, tmpdamage);
        newdamage = tmpdamage;
      } else {
        newdamage = damage;
      }
    }
  }

  void Initialize() {
    prevScore = -1;
    if (!upgrades) upgrades = new("::Upgrade::UpgradeBag");
  }

  // Runs once per tic.
  void TickStats() {
    // This ensures that the currently wielded weapon always has a WeaponInfo
    // struct associated with it. It should be pretty fast.
    let info = GetOrCreateInfoForCurrentWeapon();

    // No score integration? Nothing else to do.
    if (!::Settings.use_score_for_xp()) {
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

    upgrades.Tick();
    info.upgrades.Tick();
  }

  States {
    Spawn:
      TNT1 A 0 NoDelay Initialize();
    Poll:
      TNT1 A 1 TickStats();
      LOOP;
  }
}


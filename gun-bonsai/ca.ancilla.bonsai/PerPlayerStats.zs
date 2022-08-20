// Stats object. Each player gets one of these in their inventory.
// Holds information about the player's guns and the player themself.
// Also handles applying some damage/resistance bonuses using ModifyDamage().
#namespace TFLV;
#debug on

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
class ::PerPlayerStats : Object play {
  array<::WeaponInfo> weapons;
  ::Upgrade::UpgradeBag upgrades;
  uint XP;
  uint level;
  ::WeaponInfo infoForCurrentWeapon;
  int prevScore;
  Actor owner;

  // HACK HACK HACK
  // The various level up menus need to be able to get a handle to the specific
  // UpgradeGiver associated with that menu, so it puts itself into this field
  // just before opening the menu and clears it afterwards.
  // This is also used to check if an upgrade giver is currently awaiting a menu
  // response, in which case other upgrade givers will block (since it's possible
  // to have up to three upgrade givers going off at once).
  ::UpgradeGiver currentEffectGiver;

  static ::PerPlayerStats GetStatsFor(Actor pawn) {
    let realpawn = PlayerPawn(pawn);
    if (!realpawn) return null;
    return ::EventHandler(StaticEventHandler.Find("::EventHandler")).GetStatsFor(realpawn);
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
    stats.wxp = floor(info.XP);
    stats.wmax = info.maxXP;
    stats.wlvl = info.level;
    stats.wname = info.wpn.GetTag();
    stats.wupgrades = info.upgrades;
    stats.effect = info.ld_info.currentEffectName;
    return true;
  }

  // Return the WeaponInfo for the currently readied weapon.
  // Returns null if:
  // - no weapon is equipped
  // - the equipped weapon does not have an associated WeaponInfo
  // - the associated WeaponInfo is not stored in infoForCurrentWeapon
  // The latter two cases should only happen for one tic after switching weapons,
  // and anything calling this should be null-checking anyways.
  ::WeaponInfo GetInfoForCurrentWeapon() const {
    if (!owner || !owner.player) return null;
    Weapon wielded = owner.player.ReadyWeapon;
    if (wielded && infoForCurrentWeapon && infoForCurrentWeapon.wpn == wielded) {
      return infoForCurrentWeapon;
    }
    return null;
  }

  // Return the WeaponInfo associated with the given weapon. Unlike
  // GetInfoForCurrentWeapon(), this always searches the entire info list, so
  // it's slower, but will find the info for any weapon as long as it's been
  // wielded at least once and is still bound to its info object.
  ::WeaponInfo GetInfoFor(Weapon wpn) const {
    for (int i = 0; i < weapons.size(); ++i) {
      if (weapons[i].wpn == wpn) {
        return weapons[i];
      }
    }
    return null;
  }

  // Called every tic to ensure that the currently wielded weapon has associated
  // info, and that info is stored in infoForCurrentWeapon.
  // Returns infoForCurrentWeapon.
  // Note that if the player does not currently have a weapon equipped, this
  // sets infoForCurrentWeapon to null and returns null.
  ::WeaponInfo CreateInfoForCurrentWeapon() {
    // Fastest path -- WeaponInfo is already initialized and selected.
    if (GetInfoForCurrentWeapon()) return infoForCurrentWeapon;

    // Otherwise we need to at least select it. This will return it if it
    // already exists, rebinding an existing compatible WeaponInfo or creating
    // a new one if needed.
    // It is guaranteed to succeed.
    infoForCurrentWeapon = GetOrCreateInfoFor(owner.player.ReadyWeapon);
    return infoForCurrentWeapon;
  }

  bool weaponinfo_dirty;
  ::WeaponInfo RebuildWeaponInfo() {
    if (weaponinfo_dirty) {
      DEBUG("Dirty flag set, full weaponinfo rebuild triggered for %s.", TAG(owner));
      for (Inventory inv = owner.inv; inv; inv = inv.inv) {
        let wep = Weapon(inv);
        if (wep) {
          DEBUG("Rebuilding weaponinfo for %s", TAG(wep));
          GetOrCreateInfoFor(wep);
        }
      }
      weaponinfo_dirty = false;
    }
    return CreateInfoForCurrentWeapon();
  }

  // If a WeaponInfo already exists for this weapon, return it.
  // Otherwise, if a compatible orphaned WeaponInfo exists, rebind and return that.
  // Otherwise, create a new WeaponInfo, bind it to this weapon, add it to the
  // weapon info list, and return it.
  ::WeaponInfo GetOrCreateInfoFor(Weapon wpn) {
    if (!wpn) return null;

    // Fast path -- we already have a WeaponInfo for the player's current weapon
    // and just need to find it.
    let info = GetInfoFor(wpn);

    // Slow path -- no associated WeaponInfo, but there might be one we can
    // re-use, depending on the upgrade binding settings.
    if (!info) info = BindExistingInfoTo(wpn);

    // Slowest path -- create a new WeaponInfo and stick it to this weapon.
    if (!info) {
      info = new("::WeaponInfo");
      info.Init(wpn);
      weapons.push(info);
    }

    // Clean up orphaned WeaponInfos.
    PruneStaleInfo();
    return info;
  }

  // Given a weapon, try to find a compatible existing unused WeaponInfo we can
  // attach to it.
  ::WeaponInfo BindExistingInfoTo(Weapon wpn) {
    for (int i = 0; i < weapons.size(); ++i) {
      DEBUG("Checking if %s can host info for %s", TAG(wpn), weapons[i].wpnClass);
      if (weapons[i].CanRebindTo(wpn)) {
        weapons[i].Rebind(wpn);
        return weapons[i];
      }
    }
    return null;
  }

  // Delete WeaponInfo entries for weapons that don't exist anymore.
  void PruneStaleInfo() {
    // Only do this in BIND_WEAPON mode. In other binding modes the WeaponInfos
    // can be rebound to new weapons.
    if (::Settings.upgrade_binding_mode() != TFLV_BIND_WEAPON) return;
    for (int i = weapons.size() - 1; i >= 0; --i) {
      if (!weapons[i].wpn) {
        weapons.Delete(i);
      }
    }
  }

  // Add XP to the player. This is called by weapons when they level up to track
  // progress towards player-level upgrades.
  void AddPlayerXP(uint xp) {
    let maxXP = ::Settings.gun_levels_per_player_level();
    self.XP += xp;
    if (self.XP >= maxXP && self.XP - xp < maxXP) {
      Fanfare();
    }
  }

  void Fanfare() {
    EventHandler.SendNetworkEvent("bonsai-level-up", 0, self.level+1);
    if (::Settings.levelup_flash()) {
      owner.A_SetBlend("FF FF FF", 0.8, 40);
    }
    if (::Settings.levelup_sound() != "") {
      owner.A_StartSound(::Settings.levelup_sound(), CHAN_AUTO,
        CHANF_OVERLAP|CHANF_UI|CHANF_NOPAUSE|CHANF_LOCAL);
    }
    if (::Settings.upgrade_choices_per_player_level() == 1) {
      // If autochoose is on, immediately pick an upgrade for the player.
      StartLevelUp();
    } else {
      owner.A_Log("You leveled up!", true);
      // Earlier versions automatically opened the level-up screen, on the assumption
      // that the player had just closed a weapon level-up screen. However, (a)
      // with the addition of autochoose this is no longer a safe assumption, and
      // (b) this caused problems for some players where they'd close the weapon
      // screen and immediately start blasting, causing them to choose the wrong
      // player upgrade.
    }
  }

  bool StartLevelUp() {
    if (self.XP < ::Settings.gun_levels_per_player_level()) return false;
    let giver = ::PlayerUpgradeGiver(owner.GiveInventoryType("::PlayerUpgradeGiver"));
    giver.stats = self;
    return true;
  }

  void FinishLevelUp(::Upgrade::BaseUpgrade upgrade) {
    let maxXP = ::Settings.gun_levels_per_player_level();
    if (!upgrade) {
      // Player level-ups are expensive, so we take away *half* of a level's
      // worth of XP.
      XP -= max(1, maxXP/2);
      owner.A_Log("Level-up rejected!", true);
      return;
    }

    XP -= maxXP;
    ++level;
    upgrades.AddUpgrade(upgrade);
    owner.A_Log(
      string.format("You gained a level of %s!", upgrade.GetName()),
      true);
  }

  // Add XP to the current weapon.
  void AddXP(double xp) {
    ::WeaponInfo info = GetInfoForCurrentWeapon();
    if (!info) return;
    info.AddXP(xp);
  }

  double GetXPForDamage(Actor target, uint damage) const {
    if (target.health < 0) {
      // No bonus XP for overkills.
      damage += target.health;
    }
    double xp = max(0, damage) * ::Settings.damage_to_xp_factor();
    DEBUG("XPForDamage: damage=%d, xp=%.1f", damage, xp);
    if (target.GetSpawnHealth() > 100) {
      // Enemies with lots of HP get a log-scale XP bonus.
      // This works out to about a 1.8x bonus for Archviles and a 2.6x bonus
      // for the Cyberdemon.
      xp = xp * (log10(target.GetSpawnHealth()) - 1);
      DEBUG("After hp bonus xp is: %.1f", xp);
    }
    return xp;
  }

  // Handlers for events that player/gun upgrades may be interested in.
  // These are called from the EventManager on the corresponding world events,
  // and call the handlers on the upgrades in turn.
  // Avoid infinite recursion is handled by the UpgradeBag, which checks the
  // priority of the inciting event against the priority of each upgrade.
  void OnProjectileCreated(Actor shot) {
    upgrades.OnProjectileCreated(owner, shot);
    let info = GetInfoForCurrentWeapon();
    if (info) info.upgrades.OnProjectileCreated(owner, shot);
  }

  void OnDamageDealt(Actor shot, Actor target, uint damage) {
    DEBUG("OnDamageDealt: %d vs. %s via %s",
      damage, TAG(target), TAG(shot));
    upgrades.OnDamageDealt(owner, shot, target, damage);
    // Record whether it was a missile or a projectile, for the purposes of
    // deciding what kinds of upgrades to spawn.
    let info = GetInfoForCurrentWeapon();
    if (!info) return;
    info.upgrades.OnDamageDealt(owner, shot, target, damage);
    AddXP(GetXPForDamage(target, damage));

    if (!shot || shot.weaponspecial == ::Upgrade::PRI_MISSING)
      info.InferWeaponTypeFromDamage(owner, shot, target);
  }

  void OnDamageReceived(Actor shot, Actor attacker, uint damage) {
    upgrades.OnDamageReceived(owner, shot, attacker, damage);
    let info = GetInfoForCurrentWeapon();
    if (!info) return;
    info.upgrades.OnDamageReceived(owner, shot, attacker, damage);
  }

  void OnKill(Actor shot, Actor target) {
    upgrades.OnKill(PlayerPawn(owner), shot, target);
    let info = GetInfoForCurrentWeapon();
    if (!info) return;
    info.upgrades.OnKill(PlayerPawn(owner), shot, target);
  }

  // Apply all upgrades with ModifyDamageReceived/Dealt handlers here.
  // At this point the damage has not yet been inflicted; see OnDamageDealt/
  // OnDamageReceived for that, as well as for XP assignment.
  void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    if (damage <= 0) {
      return;
    }
    ::WeaponInfo info = GetInfoForCurrentWeapon();
    if (passive) {
      // Incoming damage.
      DEBUG("MD(p): %s <- %s <- %s (%d/%s) flags=%X",
        TAG(owner), TAG(inflictor), TAG(source),
        damage, damageType, flags);

      // TODO: this (and ModifyDamageDealt below) should take into account the
      // difference between current and original damage
      double tmpdamage = upgrades.ModifyDamageReceived(owner, inflictor, source, damage);
      if (info)
        tmpdamage = info.upgrades.ModifyDamageReceived(owner, inflictor, source, tmpdamage);
      newdamage = tmpdamage;
    } else {
      DEBUG("MD: %s -> %s -> %s (%d/%s) flags=%X",
        TAG(owner), TAG(inflictor), TAG(source),
        damage, damageType, flags);
      // Outgoing damage. 'source' is the *target* of the damage.
      let target = source;
      if (!target.bISMONSTER || target.bFRIENDLY || source == owner) {
        // Damage bonuses and XP assignment apply only when attacking monsters,
        // not decorations, friendly NPCs, or yourself.
        newdamage = damage;
        return;
      }

      double tmpdamage = upgrades.ModifyDamageDealt(owner, inflictor, source, damage);
      if (info)
        tmpdamage = info.upgrades.ModifyDamageDealt(owner, inflictor, source, tmpdamage);
      newdamage = tmpdamage;
    }
  }

  // This is called both when first created, and when reassigned to a new PlayerPawn
  // (e.g. because of a load game operation). So it should initialize any missing
  // fields but not clear valid ones.
  void Initialize(Actor owner) {
    DEBUG("Initializing PerPlayerStats for %s", TAG(owner));
    weaponinfo_dirty = true; // Force a full rebuild of the weaponinfo on startup.
    prevScore = -1;
    if (!upgrades) upgrades = new("::Upgrade::UpgradeBag");
    self.owner = owner;
    upgrades.owner = owner;
  }

  // Runs once per tic.
  void TickStats() {
    if (!owner || !owner.player) return;
    // This ensures that the currently wielded weapon always has a WeaponInfo
    // struct associated with it. It should be pretty fast, especially in the
    // common case where the weapon already has a WeaponInfo associated with it.
    // If the weaponinfo_dirty flag is set, it will do a full rebuild, scanning
    // the player's entire inventory and building info for all of their weapons.
    let info = RebuildWeaponInfo();

    // Run on-tick effects for upgrades.
    upgrades.Tick();
    if (info) info.upgrades.Tick();

    // No score integration? Nothing else to do.
    if (::Settings.score_to_xp_factor() <= 0) {
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
      DEBUG("Score changed, adding %d points -> %.1f xp",
        owner.score - prevScore, (owner.score - prevScore) * ::Settings.score_to_xp_factor());
      AddXP((owner.score - prevScore) * ::Settings.score_to_xp_factor());
      prevScore = owner.score;
    }
  }
}


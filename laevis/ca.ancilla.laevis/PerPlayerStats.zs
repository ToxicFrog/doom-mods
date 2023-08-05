// Stats object. Each player gets one of these in their inventory.
// Holds information about the player's guns and the player themself.
// Also handles applying some damage/resistance bonuses using ModifyDamage().
#namespace TFLV;
#debug off;

// Used to get all the information needed for the UI.
struct ::CurrentStats {
  // Stats for current weapon.
  ::WeaponInfo winfo;
  // Name of current weapon.
  string wname;
  // Currently active weapon effect.
  string effect;
}

class ::PerPlayerStats : Object play {
  array<::WeaponInfo> weapons;
  ::WeaponInfo infoForCurrentWeapon;
  ::PerPlayerStatsProxy proxy;
  Actor owner;

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

    stats.winfo = info;
    stats.wname = info.wpn.GetTag();
    stats.effect = info.currentEffectName;
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
    DEBUG("CreateInfoForCurrentWeapon: fastpath failed");

    // Otherwise we need to at least select it. GetOrCreateInfoFor will always
    // succeed in either re-using an existing WeaponInfo or, failing that,
    // creating a new one.
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
      if (infoForCurrentWeapon) {
        // Force CreateInfoForCurrentWeapon to re-select the active info and
        // re-activate it.
        infoForCurrentWeapon = null;
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

    return info;
  }

  // Given a weapon, try to find a compatible existing unused WeaponInfo we can
  // attach to it.
  ::WeaponInfo BindExistingInfoTo(Weapon wpn) {
    for (int i = 0; i < weapons.size(); ++i) {
      DEBUG("Checking if %s can host info for %s", TAG(wpn), weapons[i].wpnClass);
      if (weapons[i].CanRebindTo(wpn)) {
        DEBUG(" -- it can! rebinding");
        weapons[i].Rebind(wpn);
        return weapons[i];
      }
    }
    return null;
  }

  // This is called both when first created, and when reassigned to a new PlayerPawn
  // (e.g. because of a load game operation). So it should initialize any missing
  // fields but not clear valid ones.
  uint id;
  void Initialize(::PerPlayerStatsProxy proxy) {
    DEBUG("Initializing PerPlayerStats for %s", TAG(owner));
    if (!id) {
      DEBUG("this is NEW, giving it id=%d", gametic);
      id = gametic;
    } else {
      DEBUG("this is OLD, id=%d", id);
    }
    weaponinfo_dirty = true; // Force a full rebuild of the weaponinfo on startup.
    self.proxy = proxy;
    self.owner = proxy.owner;
  }

  // Runs once per tic.
  void TickStats() {
    if (!owner || !owner.player) return;
    // This ensures that the currently wielded weapon always has a WeaponInfo
    // struct associated with it. It should be pretty fast, especially in the
    // common case where the weapon already has a WeaponInfo associated with it.
    // If the weaponinfo_dirty flag is set, it will do a full rebuild, scanning
    // the player's entire inventory and building info for all of their weapons.
    RebuildWeaponInfo();
  }
}

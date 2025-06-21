// Info about a single weapon. These are held by the PerPlayerStats and each
// one records information about one of the player's weapons.
// It's also responsible for handling weapon level-ups.
#namespace TFLV;

class ::WeaponInfo : Object play {
  // At the moment "wpn" is used both as a convenient way to remember a reference
  // to the weapon itself, and as the key for the info lookup when the caller has
  // a weapon but not the WeaponInfo.
  // We call it "wpn" rather than "weapon" because ZScript gets super confused
  // if we have both a type and an instance variable in scope with the same name.
  // Sigh.
  Weapon wpn;
  string wpnClass;
  ::PerPlayerStats stats;
  ::Upgrade::UpgradeBag upgrades;
  double XP;         // total XP earned ever
  double maxXP;      // XP at which next level is earned
  uint level;        // current level, resets to 0 on respec
  uint bonus_levels; // "free" levels that don't use XP and can't be rerolled, used when respeccing

  // Called when a new WeaponInfo is created. This should initialize the entire object.
  void Init(Weapon wpn) {
    DEBUG("Initializing WeaponInfo for %s", TAG(wpn));
    upgrades = new("::Upgrade::UpgradeBag");
    Rebind(wpn);
    XP = 0;
    level = 0;
    DEBUG("WeaponInfo initialize, class=%s level=%d xp=%d/%d",
        wpnClass, level, XP, maxXP);
  }

  // Called when this WeaponInfo is being reassociated with a new weapon. It
  // should keep most of its stats.
  void Rebind(Weapon wpn) {
    self.wpn = wpn;
    if (self.wpnClass != wpn.GetClassName()) {
      // Rebinding to a weapon of an entirely different type. Reset the attack
      // modality inference counters.
      self.wpnClass = wpn.GetClassName();
      self.ResetTypeInference();
      ::RC.GetRC().Configure(self);
      if (!wpn.bPOWERED_UP || !maxXP)
        // If this is not a PoweredUp weapon, recalculate max XP as well. If it is
        // powered up, assume that we're using the max XP for it's unpowered sister.
        self.maxXP = GetXPForLevel(level+1);
    }
  }

  void ToggleUpgrade(uint index) {
    let upgrade = upgrades.upgrades[index];
    upgrade.enabled = !upgrade.enabled;
    if (upgrade.enabled) {
      upgrade.OnActivate(stats, self);
    } else {
      upgrade.OnDeactivate(stats, self);
    }
  }

  void TuneUpgrade(uint index, int amount) {
    let upgrade = upgrades.upgrades[index];
    if (!upgrade.enabled) return;
    let old_level = upgrade.level;
    upgrade.level = clamp(upgrade.level + amount, 1, upgrade.max_level);
    if (old_level != upgrade.level) {
      upgrade.OnDeactivate(stats, self);
      upgrade.OnActivate(stats, self);
    }
  }

  void OnActivate() {
    self.upgrades.OnActivate(stats, self);
  }
  void OnDeactivate() {
    self.upgrades.OnDeactivate(stats, self);
  }

  // List of upgrade classes that are unavailable on this weapon, even if they
  // would normally spawn.
  array<string> disabled_upgrades;
  void DisableUpgrades(array<string> upgrades) {
    disabled_upgrades.copy(upgrades);
  }
  bool CanAcceptUpgrade(string upgrade) {
    return disabled_upgrades.find(upgrade) == disabled_upgrades.size();
  }

  // List of classes that this weapon is considered equivalent to.
  array<string> equivalencies;
  void SetEquivalencies(array<string> classes) {
    equivalencies.copy(classes);
  }

  bool IsEquivalentTo(Weapon wpn) {
    let result = wpn.GetClassName() == self.wpnClass
      || equivalencies.find(wpn.GetClassName()) != equivalencies.size();
    DEBUG("Eqv? %s %s -> %d", wpnClass, TAG(wpn), result);
    return result;
  }

  // Given another weapon to look at, determine if this WeaponInfo can be rebound
  // to it. The actual logic used depends on the bonsai_upgrade_binding_mode cvar.
  bool CanRebindTo(Weapon wpn) {
    ::UpgradeBindingMode mode = bonsai_upgrade_binding_mode;

    // SisterWeapon overrides everything else; a weapon and its sister are always
    // considered to share a binding regardless of binding mode.
    if (self.wpn && self.wpn.SisterWeapon == wpn) return true;

    // Can't rebind at all in BIND_WEAPON mode under normal circumstances.
    // As a special case, we will permit rebinds if:
    // - the new weapon has a different class from the old one;
    // - the old weapon no longer exists;
    // - the two classes are marked equivalent in BONSAIRC.
    if (mode == ::BIND_WEAPON) {
      DEBUG("BIND_WEAPON reuse check: orphaned=%d equivalent=%d",
        self.wpn == null, IsEquivalentTo(wpn));
      return
        self.wpnClass != wpn.GetClassName()
        && self.wpn == null
        && IsEquivalentTo(wpn);
    }

    // In class-bound mode, all weapons of the same type share the same WeaponInfo.
    // When you switch weapons, the WeaponInfo for that type gets rebound to the
    // newly wielded weapon.
    if (mode == ::BIND_CLASS) {
      return IsEquivalentTo(wpn);
    }

    // In inheritable weapon-bound mode, a weaponinfo is only reusable if the
    // weapon it was bound to is no longer carried by the player.
    if (mode == ::BIND_WEAPON_INHERITABLE) {
      // We need IsReallyInInventory here because sometimes, for some reason,
      // PlayerPawn.RemoveInventory(i) doesn't set i.owner to null, even though
      // it absolutely should and the source code says it does, and this is most
      // obvious when dealing with Universal Pistol Start.
      return (self.wpn == null || self.wpn.owner == null || !IsReallyInInventory(wpn.owner, self.wpn))
        && self.IsEquivalentTo(wpn);
    }

    ThrowAbortException("Unknown UpgradeBindingMode %d!", mode);
    return false;
  }

  bool IsReallyInInventory(Actor stack, Actor needle) {
    for (Inventory inv = stack.inv; inv; inv = inv.inv) {
      if (inv == needle) return true;
    }
    return false;
  }

  // Returns the cost to get from level 0 to the given level. This is integral
  // of the XP curve from 0 to the given level.
  // We can do this just by iterating over the XP cost for each level, but
  // instead we implement the closed form of each here.
  double TotalXPForLevel(uint level) const {
    switch (bonsai_xp_curve) {
      case 0:  // constant
        return GetBaseXP() * level;
      case 1:  // linear. Total XP is the nth triangle number.
        return GetBaseXP() * (level * (level+1)) / 2;
      case 2:  // quadratic. Total XP is sum of squares, which has closed form n(n+1)(2n+1)/6
        return GetBaseXP() * (level * (level+1) * (2*level + 1))/6;
      case 3:  // cubic. This is just the nth triangle number squared. Handy!
        return GetBaseXP() * ((level * (level+1)) / 2)**2;
      case 4:  // exponential
        return GetBaseXP() * (2**level - 1);
    }
    // Should never happen
    return 1e9999;
  }

  // Returns the cost to reach the given level from the previous level, e.g.
  // GetXPForLevel(4) tells you the cost to get from level 3 to level 4.
  double GetXPForLevel(uint level) const {
    switch (bonsai_xp_curve) {
      case 0:  // constant
        return GetBaseXP();
      case 1:  // linear
        return GetBaseXP() * level;
      case 2:  // quadratic
        return GetBaseXP() * level ** 2;
      case 3:  // cubic
        return GetBaseXP() * level ** 3;
      case 4:  // exponential
        // Check here because at level 0 we want to return 0, not half the
        // base cost.
        return level ? (GetBaseXP() * 2 ** (level-1)) : 0.0;
    }
    // Should never happen
    return 1e9999;
  }

  // Returns base XP cost for this weapon, i.e. the reference XP cost to go from
  // level 0 to level 1. This is configured by the user but may be modified for
  // certain classes of weapons.
  double GetBaseXP() const {
    double mul = 1.0;
    if (IsMelee()) {
      mul = min(mul, bonsai_level_cost_mul_for_melee);
    }
    if (IsWimpy()) {
      mul = min(mul, bonsai_level_cost_mul_for_wimpy);
    }
    return bonsai_base_level_cost * mul;
  }

  void AddXP(double newXP) {
    if (IsIgnored()) return;
    DEBUG("Adding XP: %.3f + %.3f", XP, newXP);
    XP += newXP;
    DEBUG("XP is now %.3f", XP);
    let xp_since = XP - GetXPForLevel(level);
    if (XP >= maxXP && XP - newXP < maxXP) {
      Fanfare();
    }
  }

  void Fanfare() {
    EventHandler.SendNetworkEvent("bonsai-level-up", 1, self.level+1);
    let flash = ::Settings.levelup_flash();
    if (flash) {
      wpn.owner.A_SetBlend(flash, 0.8, 40);
    }
    if (::Settings.levelup_sound() != "") {
      wpn.owner.A_StartSound(::Settings.levelup_sound(), CHAN_AUTO,
        CHANF_OVERLAP|CHANF_UI|CHANF_NOPAUSE|CHANF_LOCAL);
    }
    if (0 <= bonsai_upgrade_choices_per_gun_level && bonsai_upgrade_choices_per_gun_level <= 1) {
      StartLevelUp();
    } else {
      wpn.owner.A_Log(string.format(
        StringTable.Localize("$TFLV_MSG_WEAPON_LEVELUP_READY"),
        wpn.GetTag()),
        true);
    }
  }

  // Amount of XP it took to reach this level.
  double BaseXP() { return TotalXPForLevel(self.level); }
  // Amount of XP we've gained since reaching this level.
  double LevelXP() { return XP - BaseXP(); }

  uint CountPendingLevels() {
    uint pending = bonus_levels;
    for (uint lv = level+1; TotalXPForLevel(lv) <= xp; ++lv) { ++pending; }
    return pending;
  }

  bool StartLevelUp() {
    if (!CountPendingLevels()) return false;

    let giver = ::WeaponUpgradeGiver(wpn.owner.GiveInventoryType("::WeaponUpgradeGiver"));
    giver.wielded = self;

    if (bonsai_respec_interval) {
      // Check if any of the pending levels would trigger a respec.
      for (uint i = level+1; i <= level+CountPendingLevels(); ++i) {
        if (i % bonsai_respec_interval == 0) {
          // Respec triggered. Clear all existing upgrades.
          OnDeactivate(); upgrades.Clear();
          bonus_levels = level;
          break;
        }
      }
    }

    giver.nrof = CountPendingLevels();  // Includes bonus_levels
    return true;
  }

  void RejectLevelUp() {
    if (bonus_levels) {
      --bonus_levels;
    } else {
      // Don't adjust maxXP -- they didn't gain a level.
      XP -= maxXP;
    }
    wpn.owner.A_Log(StringTable.Localize("$TFLV_MSG_LEVELUP_REJECTED"), true);
    if (XP >= maxXP) Fanfare();
    return;
  }

  void FinishLevelUp(::Upgrade::BaseUpgrade upgrade) {
    if (bonus_levels) {
      --bonus_levels;
    } else {
      ++level;
      ::PerPlayerStats.GetStatsFor(wpn.owner).AddPlayerXP(1);
      maxXP = TotalXPForLevel(level+1);
    }
    DEBUG("Level-up completed! xp=%d, base=%d, since=%d, next=%d",
      xp, BaseXP(), LevelXP(), maxXP);

    if (upgrade) {
      upgrades.AddUpgrade(upgrade).OnActivate(stats, self);
      wpn.owner.A_Log(string.format(
          StringTable.Localize("$TFLV_MSG_WEAPON_LEVELUP"),
          wpn.GetTag(), upgrade.GetName()),
        true);
    }
  }
}

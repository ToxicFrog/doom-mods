// Info about a single weapon. These are held by the PerPlayerStats and each
// one records information about one of the player's weapons.
// It's also responsible for handling weapon level-ups.
#namespace TFLV;

class ::WeaponInfo : Object play {
  // At the moment "weapon" is used both as a convenient way to remember a reference
  // to the weapon itself, and as the key for the info lookup when the caller has
  // a weapon but not the WeaponInfo.
  Weapon weapon;
  string weaponType;
  ::Upgrade::UpgradeBag upgrades;
  double XP;
  uint maxXP;
  uint level;
  // Tracking for how much this gun does hitscans vs. projectiles.
  // Use doubles rather than uints so that at high values it saturates rather
  // than overflowing.
  double hitscan_shots;
  double projectile_shots;

  ::LegendoomWeaponInfo ld_info;

  // Called when a new WeaponInfo is created. This should initialize the entire object.
  void Init(Actor wpn) {
    DEBUG("Initializing WeaponInfo for %s", TAG(wpn));
    upgrades = new("::Upgrade::UpgradeBag");
    ld_info = new("::LegendoomWeaponInfo");
    ld_info.Init(self);
    Rebind(wpn);
    XP = 0;
    level = 0;
    maxXP = GetXPForLevel(level+1);
    DEBUG("WeaponInfo initialize, class=%s level=%d xp=%d/%d",
        weaponType, level, XP, maxXP);
  }

  // Called when this WeaponInfo is being reassociated with a new weapon. It
  // should keep most of its stats.
  void Rebind(Actor wpn) {
    self.weapon = Weapon(wpn);
    self.upgrades.owner = self.weapon.owner;
    if (self.weaponType != wpn.GetClassName()) {
      // Rebinding to a weapon of an entirely different type. Reset the attack
      // modality inference counters.
      self.weaponType = wpn.GetClassName();
      hitscan_shots = 0;
      projectile_shots = 0;
    }
    ld_info.Rebind(self);
  }

  // Heuristics for guessing whether this is a projectile or hitscan weapon.
  // Note that for some weapons, both of these may return true, e.g. in the case
  // of a weapon that has a hitscan primary and projectile alt-fire that both
  // get used frequency.
  // The heuristic we use is that if more than 20% of the attacks made with this
  // weapon are hitscan, it's a hitscan weapon, and similarly for projectile attacks.
  // We have this threshold to limit false positives in the case of e.g. mods
  // that add offhand grenades that get attributed to the current weapon, or
  // weapons that have a projectile alt-fire that is used only very rarely.
  bool IsHitscanWeapon() {
    return hitscan_shots / 4 > projectile_shots;
  }

  bool IsProjectileWeapon() {
    return projectile_shots / 4 > hitscan_shots;
  }

  uint GetXPForLevel(uint level) const {
    uint XP = ::Settings.base_level_cost() * level;
    if (weapon.bMeleeWeapon) {
      XP *= ::Settings.level_cost_mul_for("melee");
    }
    if (weapon.bWimpy_Weapon) {
      XP *= ::Settings.level_cost_mul_for("wimpy");
    }
    // For some reason it can't resolve bExplosive and bBFG
    // if (weapon.bExplosive) {
    //   XP *= ::Settings.level_cost_mul_for("explosive");
    // }
    // if (weapon.bBFG) {
    //   XP *= ::Settings.level_cost_mul_for("bfg");
    // }
    DEBUG("GetXPForLevel: level %d -> XP %.1f", level, XP);
    return XP;
  }

  void AddXP(double newXP) {
    DEBUG("Adding XP: %.3f + %.3f", XP, newXP);
    XP += newXP;
    DEBUG("XP is now %.3f", XP);
    if (XP >= maxXP && XP - newXP < maxXP) {
      Fanfare();
    }
  }

  void Fanfare() {
    weapon.owner.A_Log(
      string.format("Your %s is ready to level up!", weapon.GetTag()),
      true);
    weapon.owner.A_SetBlend("00 80 FF", 0.8, 40);
    weapon.owner.A_SetBlend("00 80 FF", 0.4, 350);
    weapon.owner.A_StartSound("bonsai/gunlevelup", CHAN_AUTO,
      CHANF_OVERLAP|CHANF_UI|CHANF_NOPAUSE|CHANF_LOCAL);
  }

  bool StartLevelUp() {
    if (XP < maxXP) return false;

    let giver = ::WeaponUpgradeGiver(weapon.owner.GiveInventoryType("::WeaponUpgradeGiver"));
    giver.wielded = self;

    if (::Settings.have_legendoom()
        && ::Settings.gun_levels_per_ld_effect() > 0
        && (level % ::Settings.gun_levels_per_ld_effect()) == 0) {
      let ldGiver = ::LegendoomEffectGiver(weapon.owner.GiveInventoryType("::LegendoomEffectGiver"));
      ldGiver.info = self.ld_info;
    }

    return true;
  }

  void FinishLevelUp(::Upgrade::BaseUpgrade upgrade) {
    XP -= maxXP;
    if (!upgrade) {
      // Don't adjust maxXP -- they didn't gain a level.
      weapon.owner.A_Log("Level-up rejected!", true);
      if (XP >= maxXP) Fanfare();
      return;
    }

    ++level;
    ::PerPlayerStats.GetStatsFor(weapon.owner).AddPlayerXP(1);
    maxXP = GetXPForLevel(level+1);
    upgrades.AddUpgrade(upgrade);
    weapon.owner.A_Log(
      string.format("Your %s gained a level of %s!",
        weapon.GetTag(), upgrade.GetName()),
      true);
    if (XP >= maxXP) Fanfare();
  }
}

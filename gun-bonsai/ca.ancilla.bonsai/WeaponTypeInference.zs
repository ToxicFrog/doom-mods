#namespace TFLV;

extend class ::WeaponInfo {
  // Overrides from BONSAIRC;
  ::WeaponType typeflags;
  // Counters for different kinds of attacks. These are all doubles so that over
  // the course of a long game they will saturate rather than wrapping around.
  double total;
  // Fundamental weapon types (hitscan/projectile/melee).
  // More than one of these can in principle be true at once.
  double hitscans;
  double projectiles;
  double avg_range; // running average of mean range to target, used to determine IsMelee()
  // Additional modifiers.
  double fastprojectiles;
  double bouncers;
  double seekers;
  double rippers;
  // Burstfire tracking.
  // TODO: write this. Probably something like:
  // - if last_tic != tic, set last_tic = tic and reset burst counter
  // - if last_tic == tic, increment burst counter
  // - when resetting burst counter, if >1, add it to total_burst and increment
  //   burst_size_counter

  void ResetTypeInference() {
    total = 0.01; // avoid division by zero because gzdoom traps if that happens
    hitscans = projectiles = avg_range = 0;
    fastprojectiles = bouncers = seekers = rippers = 0;
  }

  void InfoLine(string title, double count) {
    console.printf("%12s %f (%0.2f)", title, count, count/total);
  }

  void DumpTypeInfo() {
    console.printf("Weapon type inference:");
    console.printf("%12s %04X", "BONSAIRC", typeflags);
    console.printf("%12s %f", "total", total);
    InfoLine("hitscan", hitscans);
    InfoLine("projectile", projectiles);
    console.printf("%12s %f", "avg.range", avg_range);
    InfoLine("fast", fastprojectiles);
    InfoLine("bouncer", bouncers);
    InfoLine("ripper", rippers);
    InfoLine("seeker", seekers);
    // TODO: burstfire
  }

  void InferWeaponTypeFromProjectile(Actor shot) {
    ++projectiles;
    if (shot is "FastProjectile") ++fastprojectiles;
    if (shot.bBOUNCEONWALLS) ++bouncers;
    if (shot.bSEEKERMISSILE) ++seekers;
    if (shot.bRIPPER) ++rippers;
    // TODO: burstfire projectile tracking
  }

  // For now, only shots that actually hit something get recorded.
  void InferWeaponTypeFromDamage(Actor player, Actor shot, Actor target) {
    // Don't record mod projectiles.
    if (shot && shot.weaponspecial != ::Upgrade::PRI_MISSING) return;
    // Record fast-moving projectiles (>300 wu/tic) as hitscans, for mods like
    // HDest that use very fast projectiles to simulate bullet drop and stuff.
    if (shot && shot.bMISSILE && shot.speed < 300) {
      InferWeaponTypeFromProjectile(shot);
    } else {
      // TODO: burstfire hitscan tracking
      ++hitscans;
    }
    ++total;
    let range = player.Distance3D(target) - target.radius;
    avg_range += (range - avg_range)/total;
  }

  // Heuristics for guessing whether this is a projectile or hitscan weapon.
  // Note that for some weapons, both of these may return true, e.g. in the case
  // of a weapon that has a hitscan primary and projectile alt-fire that both
  // get used frequency.
  // The heuristic we use is that if more than 33% of the attacks made with this
  // weapon are hitscan, it's a hitscan weapon, and similarly for projectile attacks.
  // We have this threshold to limit false positives in the case of e.g. mods
  // that add offhand grenades that get attributed to the current weapon, or
  // weapons that have a projectile alt-fire that is used only very rarely.
  bool IsHitscan() const {
    if (typeflags) return typeflags & ::TYPE_HITSCAN;
    return hitscans/total > 0.33;
  }
  bool IsProjectile() const {
    if (typeflags) return typeflags & ::TYPE_PROJECTILE;
    return projectiles/total > 0.33;
  }
  bool IsMelee() const {
    if (typeflags) return typeflags & ::TYPE_MELEE;
    // This value is tricky to set.
    // Range for fists, chainsaw, Heretic staff, and Gauntlets of the Necromancer
    // is 64. Range for Strife punch dagger is 80.
    // Hexen continues to bedevil me with a range of 128 for most melee weapons
    // and 144(!) for the axe.
    // For now we just say that "melee range" is 85 and manually melee-flag
    // the Hexen weapons in BONSAIRC.
    return avg_range <= 85;
  }
  // For additional modifiers we use a cutoff of 50%.
  bool IsFastProjectile() const {
    if (typeflags) return typeflags & ::TYPE_FASTPROJECTILE;
    return fastprojectiles/total > 0.5;
  }
  bool IsSlowProjectile() const {
    return IsProjectile() && !IsFastProjectile();
  }
  bool IsRipper(bool includeUpgrades=true) const {
    if (typeflags) return typeflags & ::TYPE_RIPPER;
    return
      (includeUpgrades && upgrades.Level("::Upgrade::PiercingShots"))
      || rippers/total > 0.5;
  }
  bool IsSeeker(bool includeUpgrades=true) const {
    if (typeflags) return typeflags & ::TYPE_SEEKER;
    return
      (includeUpgrades && upgrades.Level("::Upgrade::HomingShots"))
      || seekers/total > 0.5;
  }
  bool IsBouncer(bool includeUpgrades=true) const {
    if (typeflags) return typeflags & ::TYPE_BOUNCER;
    return
      (includeUpgrades && upgrades.Level("::Upgrade::BouncyShots"))
      || bouncers/total > 0.5;
  }
  // Ignored weapons cannot earn XP or levels and have a special display in
  // the HUD.
  bool IsIgnored() const {
    if (typeflags) return typeflags & ::TYPE_IGNORE;
    return false;
  }
}

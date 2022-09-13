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
  double melees;
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
    hitscans = projectiles = melees = 0;
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
    InfoLine("melee", melees);
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
    // This is based on the "avoid melee" radius in the gzDoom AI -- enemies with
    // +AVOIDMELEE will try to stay at least this many units away from you when
    // you have a melee-flagged weapon equipped.
    // Doom/Heretic melee weapns are generally range 64. Strife is 80.
    // Hexen is 128-144.
    // let range = player.Distance3D(target) - target.radius;
    // if (range < 192) ++melees;
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
    return wpn.bMELEEWEAPON;
  }
  bool IsWimpy() const {
    return wpn.bWIMPY_WEAPON;
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

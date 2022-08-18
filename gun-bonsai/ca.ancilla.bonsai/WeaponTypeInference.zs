#namespace TFLV;

extend class ::WeaponInfo {
  // Overrides from BONSAIRC;
  ::WeaponType typeflags;
  // Counters for different kinds of attacks. These are all doubles so that over
  // the course of a long game they will saturate rather than wrapping around.
  // Fundamental weapon types.
  double total;
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

  void DumpTypeInfo() {
    console.printf("Weapon type inference:");
    console.printf("%12s %f", "BONSAIRC", typeflags);
    console.printf("%12s %f", "total", total);
    console.printf("%12s %f", "hitscan", hitscans);
    console.printf("%12s %f", "projectile", projectiles);
    console.printf("%12s %f", "melee", melees);
    console.printf("%12s %f", "fast", fastprojectiles);
    console.printf("%12s %f", "bouncy", bouncers);
    console.printf("%12s %f", "seeker", seekers);
    console.printf("%12s %f", "ripper", rippers);
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
    // This value is tricky to set.
    // Range for fists, chainsaw, Heretic staff, and Gauntlets of the Necromancer
    // is 64. Range for Strife punch dagger is 80.
    // Hexen continues to bedevil me with a range of 128 for most melee weapons
    // and 144(!) for the axe.
    // For now we just say that "melee range" is 96 and manually melee-flag
    // the Hexen weapons in BONSAIRC.
    if (player.Distance3D(target) - target.radius < 96) ++melees;
    ++total;
  }

  // Heuristics for guessing whether this is a projectile or hitscan weapon.
  // Note that for some weapons, both of these may return true, e.g. in the case
  // of a weapon that has a hitscan primary and projectile alt-fire that both
  // get used frequency.
  // The heuristic we use is that if more than 25% of the attacks made with this
  // weapon are hitscan, it's a hitscan weapon, and similarly for projectile attacks.
  // We have this threshold to limit false positives in the case of e.g. mods
  // that add offhand grenades that get attributed to the current weapon, or
  // weapons that have a projectile alt-fire that is used only very rarely.
  // For melee weapons, we require that >80% of its attacks be made in melee range.
  bool IsHitscan() const {
    if (typeflags) return typeflags & ::TYPE_HITSCAN;
    return hitscans/total > 0.25;
  }
  bool IsProjectile() const {
    if (typeflags) return typeflags & ::TYPE_PROJECTILE;
    return projectiles/total > 0.25;
  }
  bool IsMelee() const {
    if (typeflags) return typeflags & ::TYPE_MELEE;
    return melees/total > 0.8;
  }
  bool IsFastProjectile() const {
    return fastprojectiles/total > 0.5;
  }
  bool IsRipper() const {
    return rippers/total > 0.5;
  }
  bool IsSeeker() const {
    return seekers/total > 0.5;
  }
  bool IsBouncy() const {
    return bouncers/total > 0.5;
  }
  // Ignored weapons cannot earn XP or levels and have a special display in
  // the HUD.
  bool IsIgnored() const {
    if (typeflags) return typeflags & ::TYPE_IGNORE;
    return false;
  }
}

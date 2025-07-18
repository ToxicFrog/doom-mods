#namespace TFLV::Upgrade;
#debug off

class ::Registry : Object play {
  array<string> upgrade_names;
  array<string> unregistered;
  array<::BaseUpgrade> upgrades;

  static ::Registry GetRegistry() {
    let reg = TFLV::EventHandler(StaticEventHandler.Find("TFLV::EventHandler"));
    if (!reg) return null;
    return reg.UPGRADE_REGISTRY;
  }

  int FindRegistration(string upgrade) {
    let idx = upgrade_names.find(upgrade);
    if (idx == upgrade_names.size()) return -1;
    return idx;
  }

  ::BaseUpgrade FindUpgrade(string upgrade) {
    let idx = FindRegistration(upgrade);
    if (idx < 0) return null;
    return upgrades[idx];
  }

  bool IsUnregistered(string upgrade) {
    return unregistered.find(upgrade) != unregistered.size();
  }

  bool Register(string upgrade) {
    DEBUG("Register: %s", upgrade);
    if (IsUnregistered(upgrade)) {
      // Disabled by BONSAIRC.
      return false;
    }
    if (FindRegistration(upgrade) >= 0) {
      // Double-registrations are a no-op to make BONSAIRC more forgiving, and
      // are reported as successful.
      return true;
    }
    upgrade_names.push(upgrade);
    upgrades.push(::BaseUpgrade(new(upgrade)));
    return true;
  }

  void Unregister(string upgrade) {
    DEBUG("Unregister: %s", upgrade);

    if (IsUnregistered(upgrade)) return;
    unregistered.push(upgrade);

    let idx = FindRegistration(upgrade);
    if (idx < 0) return;
    upgrade_names.delete(idx);
    upgrades.delete(idx);
  }

  // Returns true if Indestructable has delegated management of lives to Gun Bonsai.
  static bool IsIndestructableDelegated() {
    return CVar.FindCVar("indestructable_starting_lives").GetInt() == 0
      && CVar.FindCVar("indestructable_lives_per_level").GetInt() == 0
      && CVar.FindCVar("indestructable_max_lives_per_level").GetInt() == 0;
  }

  //// Upgrade candidate list logic below this point. ////
  //
  // The basic concept for both player and weapon upgrades is to create a candidate
  // list of eligible upgrades, then randomly pick a subset of those for the list
  // of upgrades actually generated and presented to the player. However, the ability
  // to force upgrades into the list complicates this slightly.
  //
  // So the actual behaviour is:
  // - start with an empty list of generated upgrades and an empty list of candidates;
  // - populate the generated list with all eligible forced upgrades;
  // - populate the candidate list with all eligible upgrades not already in the generated list;
  // - pick upgrades from the candidate list at random, without replacement, and add them
  //   to the generated list until its cardinality is ≥ the requested upgrade count.

  void PickN(Array<::BaseUpgrade> dst, Array<::BaseUpgrade> src, uint n) {
    uint max = src.size();
    while (max > 0 && dst.size() < n) {
      uint i = random[::RNG_UpgradePicker](0, max-1);
      dst.push(src[i]);
      src[i] = src[--max];
    }
  }

  void AddEligibleUpgrades(
      TFLV::PerPlayerStats stats, TFLV::WeaponInfo info, Array<string> names,
      Array<::BaseUpgrade> upgrades, Array<::BaseUpgrade> exclude) {
    for (int i = 0; i < names.Size(); ++i) {
      let upgrade = FindUpgrade(names[i]);
      if (!upgrade) {
        console.printf("Warning: unknown upgrade name: %s", names[i]);
        continue;
      }
      // Don't include ineligible upgrades.
      if (exclude && exclude.Find(upgrade) < exclude.Size()) continue;
      if (stats && !upgrade.IsSuitableForPlayer(stats)) continue;
      if (info && !(upgrade.IsSuitableForWeapon(info) && info.CanAcceptUpgrade(names[i]))) continue;
      upgrades.Push(upgrade);
    }
  }

  void AddForcedUpgrades(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info, Array<::BaseUpgrade> generated) {
    Array<string> forced_names;
    bonsai_forced_upgrades.Split(forced_names, " ", TOK_SKIPEMPTY);
    AddEligibleUpgrades(stats, info, forced_names, generated, generated);
  }

  void GenerateUpgradesForPlayer(
      TFLV::PerPlayerStats stats, Array<::BaseUpgrade> generated) {
    Array<::BaseUpgrade> candidates;
    let nrof = bonsai_upgrade_choices_per_player_level;

    if (nrof == -2) {
      // Debug mode -- return all upgrades, even invalid ones.
      generated.Copy(upgrades);
      return;
    }

    AddForcedUpgrades(stats, null, generated);
    AddEligibleUpgrades(stats, null, upgrade_names, candidates, generated);

    if (nrof == -1) {
      // "All upgrades" mode
      generated.Append(candidates);
    } else {
      PickN(generated, candidates, nrof);
    }
  }

  void GenerateUpgradesForWeapon(
      TFLV::WeaponInfo info, Array<::BaseUpgrade> generated) {
    array<::BaseUpgrade> candidates;
    let nrof = bonsai_upgrade_choices_per_gun_level;

    if (nrof == -2) {
      // Debug mode -- return all upgrades, even invalid ones.
      generated.Copy(upgrades);
      return;
    }

    AddForcedUpgrades(null, info, generated);
    AddEligibleUpgrades(null, info, upgrade_names, candidates, generated);

    if (nrof == -1) {
      // "All upgrades" mode
      generated.Append(candidates);
    } else {
      PickN(generated, candidates, nrof);
    }
  }
}

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

  void PickN(Array<::BaseUpgrade> dst, Array<::BaseUpgrade> src, uint n) {
    uint max = src.size();
    while (max > 0 && dst.size() < n) {
      uint i = random[::RNG_UpgradePicker](0, max-1);
      dst.push(src[i]);
      src[i] = src[--max];
    }
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

    for (uint i = 0; i < upgrades.size(); ++i) {
      if (upgrades[i].IsSuitableForPlayer(stats))
        candidates.push(upgrades[i]);
    }

    if (nrof == -1) {
      // "All upgrades" mode
      generated.Copy(candidates);
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

    for (uint i = 0; i < upgrades.size(); ++i) {
      if (upgrades[i].IsSuitableForWeapon(info) && info.CanAcceptUpgrade(upgrade_names[i]))
        candidates.push(upgrades[i]);
    }

    if (nrof == -1) {
      // "All upgrades" mode
      generated.Copy(candidates);
    } else {
      PickN(generated, candidates, nrof);
    }
  }
}

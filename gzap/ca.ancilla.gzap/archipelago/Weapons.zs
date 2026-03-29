// Implementation of the weapon capability system.
//
// See doc/design/weapons.md for full details, but the summary is:
// - weapons and weapon grant tokens sent to us from AP are turned into speculative weapon capabilities
// - speculative weapon capabilities are flushed as in-world items without weapon locking
// - weapons picked up by the player are turned into real weapon capabilities
// - player's weapon inventory is forced to match their real wcaps
// - wcaps can be scoped to specific maps
//
// Weapon lifecycle.
// Terminology: global caps are in * scope, local caps are in map scope,
// mirrored caps are copied to all map scopes.
//
// With per-map weapons OFF:
// - starting inventory is translated into mirrored real caps
// - global weapon grants produce global s-wcaps
// - plain weapons produce global s-wcaps
// - local weapon grants shouldn't exist (but we handle them normally and emit a warning)
// - s-wcaps turn into weapon pickups
// - weapon pickups produce mirrored r-wcaps.
//
// With per-map weapons ON:
// - starting inventory is translated into mirrored r-wcaps
// - global weapon grants produce mirrored s-wcaps
// - plain weapons produce mirrored s-wcaps
// - local weapon grants produce local s-wcaps
// - s-wcaps turn into weapon pickups
// - weapon pickups produce local r-wcaps
//
// This implies that the operations we need are:
// - add mirrored r-wcap
// - add local r-wcap (which may produce a mirrored one instead if per-level is off)
// - add local s-wcap (which produces a warning if per-level is off)
// - add global s-wcap (used for global grants and plain weapons when per-level is off)
// - add mirrored s-wcap (used for global grants and plain weapons when per-level is on)

#namespace GZAP;
#debug on;

// We need to wrap these in new classes because otherwise ZScript has a wobbly.
// You can't put an Array<> or Map<> directly inside a Map's V type.
class ::PendingCaps play {
  Array<string> typenames;
}

class ::RealCaps play {
  Map<string, bool> weapons;
}

class ::WeaponCapabilities play {
  // Speculative weapon capabilities containing typenames sent to us from AP.
  // These may not be the same as what the player actually picks up depending
  // on what mods are loaded.
  Map<string, ::PendingCaps> pending;
  // Real weapon capabilities. The typenames in these should be directly
  // spawnable without worrying about replacement.
  Map<string, ::RealCaps> real;
  // If off, per-map weapon capabilities are disabled in this game, and we
  // treat all capabilities as global.
  // If on, per-map weapon capabilities are enabled, and adding a "global"
  // capability actually adds a local capabilty to each map.
  // This always starts disabled (
  bool use_per_map_caps;

  static ::WeaponCapabilities Create(::RandoState apstate, bool per_map_weapons) {
    ::WeaponCapabilities caps = new("::WeaponCapabilities");
    caps.use_per_map_caps = per_map_weapons;
    // Global scope. Only meaningful for pending caps -- "global" real caps are
    // implemented by mirroring the same capability to every scope.
    caps.pending.Insert("*", new("::PendingCaps"));
    // Per-map scopes
    foreach (name,region : apstate.regions) {
      caps.pending.Insert(name, new("::PendingCaps"));
      caps.real.Insert(name, new("::RealCaps"));
    }
    return caps;
  }

  // Add a pending global capability. In per-map mode this turns into a separate
  // pending wcap on every map (to ensure it properly gets translated into a
  // real cap on each map). In global mode we just store it as a global pending
  // cap directly.
  void AddGlobalCap(string typename) {
    if (self.use_per_map_caps) {
      foreach (name,region : ::RandoState.Get().regions) {
        AddScopedCap(name, typename);
      }
    } else {
      AddScopedCap("*", typename);
    }
  }

  // Add a pending capability to the given scope. The next time the player is
  // in that scope (which may be immediately) it will be disposed of and turned
  // into a weapon.
  void AddScopedCap(string scope, string typename) {
    DEBUG("Adding pending weapon capability (%s,%s)", scope, typename);
    if (!self.use_per_map_caps && scope != "*") {
      console.printf("\c[ORANGE][AP] Warning: requested speculative weapon capability (%s,%s) but per-map weapon capabilities are disabled for this game. Report this as a bug.", scope, typename);
    } else if (self.use_per_map_caps && scope == "*") {
      console.printf("\c[ORANGE][AP] Warning: requested speculative weapon capability (*,%s) but per-map weapon capabilities are enabled for this game. Report this as a bug.", scope, typename);
    }
    self.pending.GetIfExists(scope).typenames.Push(typename);
  }

  // Add a real global capability, granting the player the use of this weapon in
  // all scopes. Internally this is implemented by granting the capability in
  // every individual scope rather than with a separate global scope.
  void AddGlobalRealCap(Weapon thing) {
    DEBUG("adding real weapon capability (*,%s)", thing.GetClassName());
    foreach (name,region : ::RandoState.Get().regions) {
      self.real.GetIfExists(name).weapons.Insert(thing.GetClassName(), true);
    }
  }

  // Add a real capability to the given scope, allowing and requiring the player
  // to have this weapon whenever they are in this scope.
  void AddScopedRealCap(string scope, Weapon thing) {
    if (self.use_per_map_caps) {
      DEBUG("adding real weapon capability (%s,%s)", scope, thing.GetClassName());
      self.real.GetIfExists(scope).weapons.Insert(thing.GetClassName(), true);
    } else {
      DEBUG("promoting real cap (%s,%s) to mirrored", scope, thing.GetClassName());
      AddGlobalRealCap(thing);
    }
  }

  // Apply all pending wcaps in the global scope and in the player's current
  // scope.
  // Pending wcaps corresponding to weapons the player is already holding are
  // converted directly into real wcaps. Other wcaps are spawned into the game.
  void ApplyPendingCaps(string scope) {
    ::PendingCaps global = self.pending.GetIfExists("*");
    ::PendingCaps local = self.pending.GetIfExists(scope);
    DEBUG("ApplyPendingCaps(%s) global=%d local=%d", scope, global.typenames.Size(), local.typenames.Size());

    foreach (typename : global.typenames) {
      DEBUG("Applying pending global weapon capability (%s,%s)", scope, typename);
      GiveWeapon(scope, typename);
    }
    foreach (typename : local.typenames) {
      DEBUG("Applying pending local weapon capability (%s,%s)", scope, typename);
      GiveWeapon(scope, typename);
    }

    global.typenames.Clear();
    local.typenames.Clear();
  }

  void GiveWeapon(string scope, string typename) {
    // If we already have a real cap for this in this scope, ApplyRealCaps will
    // deal with it in a moment and we can just do nothing. This only really
    // works when replacements are off, as otherwise the real cap won't have a
    // typename matching the speculative one.
    if (self.real.GetIfExists(scope).weapons.CheckKey(typename)) {
      return;
    }

    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      let pawn = players[p].mo;
      if (!pawn) continue;
      let thing = pawn.FindInventory(typename);
      if (thing) {
        DEBUG(" -> converting to real cap directly");
        AddScopedRealCap(scope, Weapon(thing));
      } else {
        DEBUG(" -> spawning new weapon");
        ::Util.SpawnUnrestricted(pawn, typename, ALLOW_REPLACE);
      }
    }
  }

  void ApplyRealCaps(string scope) {
    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      if (!players[p].mo) continue;
      ApplyRealCapsToPawn(self.real.GetIfExists(scope), players[p].mo);
    }
  }

  void ApplyRealCapsToPawn(::RealCaps caps, PlayerPawn mo) {
    DEBUG("ApplyRealCapsToPawn(%s)", mo.GetTag());

    Map<string,bool> to_remove;
    let thing = mo.inv;
    while (thing) {
      let cls = thing.GetClass();
      if (cls is "Weapon") {
        DEBUG(" - %s", thing.GetClassName());
        to_remove.Insert(thing.GetClassName(), true);
      }
      thing = thing.inv;
    }

    Map<string,bool> to_add;
    foreach (typename, _ : caps.weapons) {
      if (to_remove.CheckKey(typename)) {
        // Player already has this weapon in their inventory.
        DEBUG(" = %s", typename);
        to_remove.Remove(typename);
      } else {
        DEBUG(" + %s", typename);
        to_add.Insert(typename, true);
      }
    }

    foreach (typename, _ : to_remove) {
      DEBUG("removing: %s", typename);
      mo.TakeInventory(typename, 9999);
    }
    foreach (typename, _ : to_add) {
      DEBUG("adding: %s", typename);
      mo.GiveInventory(typename, 1);
    }
  }
}

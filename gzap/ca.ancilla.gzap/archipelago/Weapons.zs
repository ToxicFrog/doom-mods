// Implementation of the weapon capability system.
//
// See doc/design/weapons.md for full details, but the summary is:
// - weapons and weapon grant tokens sent to us from AP are turned into speculative weapon capabilities
// - speculative weapon capabilities are flushed as in-world items without weapon locking
// - weapons picked up by the player are turned into real weapon capabilities
// - player's weapon inventory is forced to match their real wcaps
// - wcaps can be scoped to specific maps

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
  Map<string, ::PendingCaps> pending;
  Map<string, ::RealCaps> real;

  static ::WeaponCapabilities Create(::RandoState apstate) {
    ::WeaponCapabilities caps = new("::WeaponCapabilities");
    foreach (name,region : apstate.regions) {
      caps.pending.Insert(name, new("::PendingCaps"));
      caps.real.Insert(name, new("::RealCaps"));
    }
    return caps;
  }

  void AddGlobalCap(string typename) {
    foreach (name,region : ::RandoState.Get().regions) {
      AddScopedCap(name, typename);
    }
  }

  void AddScopedCap(string scope, string typename) {
    DEBUG("Adding pending weapon capability (%s,%s)", scope, typename);
    self.pending.GetIfExists(scope).typenames.Push(typename);
  }

  void AddGlobalRealCap(Weapon thing) {
    foreach (name,region : ::RandoState.Get().regions) {
      AddScopedRealCap(name, thing);
    }
  }

  void AddScopedRealCap(string scope, Weapon thing) {
    DEBUG("adding real weapon capability (%s,%s)", scope, thing.GetClassName());
    let caps = self.real.GetIfExists(scope);
    caps.weapons.Insert(thing.GetClassName(), true);
  }

  bool HasPendingCaps(string scope) {
    return self.pending.GetIfExists(scope).typenames.Size() > 0;
  }

  void ApplyPendingCaps(string scope) {
    DEBUG("ApplyPendingCaps(%s) %d", scope, self.pending.CheckKey(scope));
    ::PendingCaps caps = self.pending.GetIfExists(scope);
    DEBUG("capsize=%d", caps.typenames.Size());
    foreach (typename : caps.typenames) {
      DEBUG("Applying pending weapon capabilities (%s,%s)", scope, typename);
      GiveWeapon(scope, typename);
    }
    DEBUG("ApplyPendingCaps(%s) cleanup", scope);
    self.pending.GetIfExists(scope).typenames.Clear();
  }

  void GiveWeapon(string scope, string typename) {
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

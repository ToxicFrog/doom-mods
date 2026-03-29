// Weapon suppression implementation.
//
// When a weapon spawns in the world that we didn't place ourselves and that
// wasn't statically spawned in the map, CheckReplacement sees that and creates
// one of these to take its place.
//
// This actor remembers its original, and is responsible for deciding, based on
// the weapon suppression settings, whether and how the player should interact
// with it. If the settings call for it to release the original weapon or its
// ammo, it does so and evaporates.

#namespace GZAP;
#debug off;

const AP_ALLOW_WEAPONS_ALWAYS = 0;
const AP_ALLOW_WEAPONS_IF_SIBLING = 1;
const AP_ALLOW_WEAPONS_IF_TWIN = 2;
const AP_ALLOW_WEAPONS_NEVER = 3;

const AP_BLOCKED_WEAPONS_REMAIN = 0;
const AP_BLOCKED_WEAPONS_ARE_AMMO = 1;
const AP_BLOCKED_WEAPONS_DESTROYED = 2;

class ::LockedWeapon : CustomInventory {
  Class<Actor> original;

  override void PostBeginPlay() {
    self.original = ::PerLevelHandler.Get().last_replaced_actor;
    if (!self.original) {
      DEBUG("No last_replaced_weapon initializing a LockedWeapon!");
      Destroy();
      return;
    } else {
      SetTag(string.format("LockedWeapon[%s]", self.original.GetClassName()));
      DEBUG("Initializing %s", self.GetTag());
    }

    // Set sprite from original item we're encasing.
    // TODO: if it doesn't have a sprite turn into an AP error sprite.
    let thing = GetDefaultByType(self.original);
    self.sprite = thing.SpawnState.sprite;
    self.frame = thing.SpawnState.frame;
    A_SetScale(thing.scale.x, thing.scale.y);
  }

  // Like GetDefaultByType(self.original), except:
  // - it only returns valid Weapons suitable for querying slot and ammo info about, and
  // - it has special handling for WeaponGiver that returns the contained Weapon and not the container.
  readonly<Weapon> GetDefault() {
    if (!(self.original is "Weapon")) return null;
    let thing = GetDefaultByType(self.original);
    if (!thing) return null;
    if (thing is "WeaponGiver") {
      // The real weapon is the dropitem.
      string name = thing.GetDropItems().Name;
      Class<Weapon> cls = name;
      if (cls) return GetDefaultByType(cls);
    }
    return Weapon(thing);
  }

  // This requires a bit of nuance, because in addition to "no" or "yes", the
  // answer might be "no, but we turn into something else the player *can* pick
  // up".
  // So we have some helpers for checking what, exactly, we should do when the
  // player touches us.
  bool ShouldReleaseWeapon(Actor toucher) {
    // Allow OOB weapon pickups always.
    if (ap_suppress_weapon_drops == AP_ALLOW_WEAPONS_ALWAYS) {
      DEBUG("ShouldReleaseWeapon[%s]: always", self.GetTag());
      return true;
    }

    let apstate = ::RandoState.Get();

    // Allow if the player already has a weapon of the same slot.
    if (ap_suppress_weapon_drops == AP_ALLOW_WEAPONS_IF_SIBLING) {
      // Make the simplifying assumption that all players have the same slots.
      let [assigned,slot,idx] = players[0].weapons.LocateWeapon(GetDefault().GetClass());
      DEBUG("ShouldReleaseWeapon[%s]: assigned=%d slot=%d has_slot=%d", self.GetTag(), assigned, slot, apstate.HasWeaponSlot(slot));
      if (!assigned) return true; // I guess???
      return apstate.HasWeaponSlot(slot);
    }

    // Allow if the same weapon is already unlocked in AP.
    // We check both the weapon we actually contain, and the weapon it is
    // configured to be replaced with on spawn, to deal with wads like Time
    // Tripper that use their own weapons, but place the originals in the maps
    // and rely on replacement rules to spawn the new ones.
    if (ap_suppress_weapon_drops == AP_ALLOW_WEAPONS_IF_TWIN) {
      DEBUG("ShouldReleaseWeapon(%s): check for twin (replacement=%s)", self.GetTag(), GetReplacement(self.original).GetClassName());
      return apstate.HasWeapon(self.original.GetClassName())
        || apstate.HasWeapon(GetReplacement(self.original).GetClassName());
    }

    // AP_ALLOW_WEAPONS_NEVER
    DEBUG("ShouldReleaseWeapon(%s): never", self.GetTag());
    return false;
  }

  bool ShouldReleaseAmmo() {
    DEBUG("ShouldReleaseAmmo(%s): %d == %d", self.GetTag(), ap_disallowed_weapon_behaviour, AP_BLOCKED_WEAPONS_ARE_AMMO);
    return ap_disallowed_weapon_behaviour == AP_BLOCKED_WEAPONS_ARE_AMMO;
  }

  bool ShouldEvaporate() {
    DEBUG("ShouldEvaporate(%s): %d == %d", self.GetTag(), ap_disallowed_weapon_behaviour, AP_BLOCKED_WEAPONS_DESTROYED);
    return ap_disallowed_weapon_behaviour == AP_BLOCKED_WEAPONS_DESTROYED;
  }

  override bool CanPickup(Actor toucher) {
    DEBUG("Can pick up? %s %s", GetTag(), toucher.GetTag());

    // We return true if we should do something permanent on pickup, even if
    // that something isn't actually letting the player pick us up.
    return ShouldReleaseWeapon(toucher) || ShouldReleaseAmmo() || ShouldEvaporate();
  }

  override bool TryPickup(in out Actor toucher) {
    if (ShouldReleaseWeapon(toucher)) {
      // Turn into whatever we originally were
      ::Util.SpawnUnrestricted(self, self.original, ALLOW_REPLACE);
    } else if (ShouldReleaseAmmo()) {
      // Spawn ammo for whatever we originally were
      ReplaceWithAmmo(GetDefault());
    }
    // Evaporate unconditionally -- either we've already released our contents
    // or evaporation was turned on, otherwise CanPickup() would have returned
    // false and this function would not be called.
    bPickupGood = false;
    GoAwayAndDie();
    // Tell the engine the pickup failed so it doesn't try to print a pickup
    // message for us.
    return false;
  }

  void ReplaceWithAmmo(readonly<Weapon> thing) {
    // Can't figure out what ammo to spawn if we don't contain a weapon.
    if (!thing) return;

    DEBUG("ReplaceWithAmmo: %s", thing.GetTag());
    SpawnAmmo(thing.AmmoType1, thing.AmmoGive1);
    SpawnAmmo(thing.AmmoType2, thing.AmmoGive2);
  }

  void SpawnAmmo(Class<Ammo> cls, int amount) {
    if (!cls || !amount) return;
    DEBUG("SpawnAmmo: %d of %s", amount, cls.GetClassName());
    let ammo = Inventory(::Util.SpawnUnrestricted(self, cls, ALLOW_REPLACE));
    if (!ammo) return;
    DEBUG("Spawned: %s", ammo.GetTag());
    ammo.ClearCounters();
    ammo.amount = amount;
  }
}

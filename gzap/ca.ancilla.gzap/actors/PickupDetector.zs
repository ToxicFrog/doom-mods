// Inventory item that senses when the player has picked something up.
// This is used for two purposes:
// - Suppressing weapon pickups that the player doesn't have unlocked yet, and
// - Detecting when the player has picked up a dynkey and handling it.
#namespace GZAP;
#debug off;

class ::PickupDetector : Inventory {
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INVENTORY.IGNORESKILL;
    +INVENTORY.UNTOSSABLE;
    +INVENTORY.UNDROPPABLE;
    +INVENTORY.QUIET;
  }

  // In order to make sure we intercept EVERY SINGLE PICKUP, we need to be in
  // head position, as otherwise pickups might get intercepted by earlier items
  // (e.g. a duplicate weapon pickup will get intercepted by the weapon already
  // in the player's inventory and turned into ammo). However, this should only
  // happen in cases where the player already has a copy of the thing being
  // picked up, which we don't care about. So we optimistically assume that we
  // don't need to care about our position in the inventory.
  // void MoveToHead() {}

  bool RejectPickup(Inventory item) {
    item.DoPickupSpecial(owner);
    item.bPickupGood = false;
    item.GoAwayAndDie();
    return true;
  }

  bool HandleKey(::RandoState apstate, Inventory item) {
    let region = apstate.GetCurrentRegion();
    if (!region) return false;

    DEBUG("HandleKey: %s %s", region.map, item.GetClassName());

    let key = region.GetKey(item.GetClassName());
    if (!key) {
      DEBUG("  Creating new RandoKey record.");
      // The player has found a new dynkey, a key that exists in the world but
      // was not detected by the scanner or by previous tuning.
      // First emit the AP-KEY message for it.
      let scan = ::ScannedItem.Create(item, region.map);
      scan.OutputKeyInfo();

      // Now create and register the apstate's internal model of the key.
      key = apstate.RegisterKey(region.map, item.GetTag(), item.GetClassName(), -1);

      Array<string> maps; scan.GetMapsForKey(maps);
      foreach (map : maps) {
        key.AddMap(apstate, map);
      }

      // Tell the state that we are allowed to manifest this key.
      key.MarkHeld(apstate);

    } else if (::PlayEventHandler.Get().IsPretuning()) {
      // The state already knows about the key. If the player has just found it
      // lying around in the world somewhere, we should reject the pickup -- they
      // are expected to find it in the pool -- *unless* we are in pretuning mode,
      // in which case dynkeys do not exist in the pool in the first place and
      // this is the only way to get it.
      key.MarkHeld(apstate);
    }

    // At this point the apstate knows about this key. We permit it to be picked
    // up iff the apstate thinks the player should have it in their inventory.
    if (key.held && key.enabled) {
      DEBUG("  Permitting key pickup.");
      return false;
    } else {
      return RejectPickup(item);
    }
  }

  override bool HandlePickup(Inventory item) {
    let plh = ::PerLevelHandler.Get();

    // Handle weapon suppression, if enabled.
    DEBUG("HandlePickup: player found a %s", item.GetClassName());
    if (!plh.ShouldAllow(Weapon(item))) {
      DEBUG("HandlePickup: suppressing %s", item.GetClassName());
      plh.ReplaceWithAmmo(item, Weapon(item));
      return RejectPickup(item);
    }

    // Handle keys.
    if (item is "Key") {
      return HandleKey(plh.apstate, item);
    }

    return false;
  }
}

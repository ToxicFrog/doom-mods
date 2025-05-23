// Inventory item that senses when the player has picked something up.
// This is used for two purposes:
// - Suppressing weapon pickups that the player doesn't have unlocked yet, and
// - Detecting when the player has picked up a dynkey and handling it.
#namespace GZAP;
#debug on;

class ::PickupDetector : Inventory {
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INVENTORY.IGNORESKILL;
    +INVENTORY.UNTOSSABLE;
    +INVENTORY.UNDROPPABLE;
    +INVENTORY.QUIET;
  }

  // States {
  //   Spawn:
  //     TNT1 A 0;
  //     STOP;
  //   KeyCheck:
  //     TNT1 A 2;
  //     TNT1 A 0 DoKeyCheck();
  //     GOTO Spawn;
  //     STOP;
  // }

  // In order to make sure we intercept EVERY SINGLE PICKUP, we need to be in
  // head position, as otherwise pickups might get intercepted by earlier items
  // (e.g. a duplicate weapon pickup will get intercepted by the weapon already
  // in the player's inventory and turned into ammo). However, this should only
  // happen in cases where the player already has a copy of the thing being
  // picked up, which we don't care about. So we optimistically assume that we
  // don't need to care about our position in the inventory.
  // void MoveToHead() {}

  bool RejectPickup(Inventory item) {
    item.bPickupGood = false;
    item.GoAwayAndDie();
    return true;
  }

  override bool HandlePickup(Inventory item) {
    let plh = ::PerLevelHandler.Get();

    // Handle weapon suppression, if enabled.
    if (!plh.ShouldAllow(Weapon(item))) {
      DEBUG("HandlePickup: suppressing %s", item.GetClassName());
      plh.ReplaceWithAmmo(item, Weapon(item));
      return RejectPickup(item);
    }

    return false;
  }
}

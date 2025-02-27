// DEHACKED-modified items are replaced with "DehackedPickupN" actors at runtime,
// which means we can't meaningfully query them for type information. There's a
// method for querying the backing type, but it's private -- see
// https://github.com/ZDoom/gzdoom/issues/2964 for details.
// So instead, we spawn one of these and touch it, causing it to briefly manifest
// the real item, which we query.

#namespace GZAP;
#debug off;

class ::DehackedPickupProber : Actor {
  ::ScannedItem real_item;
  override bool CanReceive(Inventory item) {
    DEBUG("Probing: %s [%s]", item.GetTag(), item.GetClassName());
    if (item is "DehackedPickup") {
      DEBUG("Is DEH, lying about it");
      return true;
    }
    if (::ScannedItem.ItemCategory(item) != "") {
      DEBUG("Is not DEH, recording it");
      real_item = ::ScannedItem.Create(item);
    }
    return false;
  }
}

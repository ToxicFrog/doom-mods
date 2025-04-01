// Holds information about a single scanned item.

#namespace GZAP;

#include "./ScannedLocation.zsc"

class ::ScannedItem : ::ScannedLocation {
  string category;
  string tag;
  bool secret;

  static ::ScannedItem Create(Actor thing) {
    let loc = ::ScannedItem(new("::ScannedItem"));
    loc.category = ItemCategory(thing);
    loc.typename = thing.GetClassName();
    loc.tag = thing.GetTag();
    loc.secret = IsSecret(thing);
    loc.pos = thing.pos;

    let [newtype, ok] = ::RC.Get().GetTypename(loc.typename);
    if (ok) {
      class<Actor> cls = newtype;
      loc.typename = newtype;
      loc.tag = GetDefaultByType(cls).GetTag();
    }

    return loc;
  }

  // TODO: make "secret" field optional and emit it only on secret items
  override void Output(string mapname) {
    string secret_str = "";
    if (secret) {
      secret_str = string.format("\"secret\": %s,", ::Util.bool2str(secret));
    }

    ::Scanner.Output("ITEM", mapname, string.format(
        "\"category\": \"%s\", \"typename\": \"%s\", \"tag\": \"%s\", %s%s%s",
        category, typename, tag, secret_str, OutputSkill(), OutputPosition()));
  }

  static bool IsSecret(Actor thing) {
    return (thing.cursector.IsSecret() || thing.cursector.WasSecret());
  }

  static bool IsTool(readonly<Inventory> thing) {
    if (!thing) return false;
    return thing.bINVBAR;
  }

  static string HealthCategory(int amount) {
    if (amount >= 100) return "big-health";
    if (amount >= 25) return "medium-health";
    return "small-health";
  }

  static string ArmourCategory(int amount) {
    if (amount >= 100) return "big-armor";
    if (amount >= 25) return "medium-armor";
    return "small-armor";
  }

  static string AmmoCategory(int amount, int maxamount) {
    if (amount >= maxamount/5) return "medium-ammo";
    return "small-ammo";
  }

  // TODO: we can use inventory flags for this better than class hierarchy in many cases.
  // INVENTORY.AUTOACTIVATE - item activates when picked up
  // .INVBAR - item goes to the inventory screen and can be used later
  // .BIGPOWERUP - item is particularly powerful
  // .ISHEALTH, .ISARMOR - as it says
  // .HUBPOWER, .PERSISTENTPOWER, and .InterHubAmount allow carrying between levels
  // .COUNTITEM - counts towards the % items collected stat
  // there's also sv_unlimited_pickup to remove all limits on ammo capacity(!)
  static string ItemCategory(readonly<Actor> thing) {
    let [category, ok] = ::RC.Get().GetCategory(thing.GetClassName());
    if (ok) return category;

    if (thing is "Key" || thing is "PuzzleItem") {
      return "key"; // TODO: allow duplicate PuzzleItems but not Keys
    } else if (thing is "Weapon" || thing is "WeaponPiece") {
      return "weapon";
    } else if (thing is "BackpackItem") {
      return "big-ammo";
    } else if (thing is "MapRevealer") {
      return "map";
    } else if (thing is "PowerupGiver") {
      return "powerup";
    } else if (thing is "BasicArmorPickup") {
      return ArmourCategory(BasicArmorPickup(thing).SaveAmount);
    } else if (thing is "BasicArmorBonus") {
      return ArmourCategory(BasicArmorBonus(thing).SaveAmount);
    } else if (thing is "Health") {
      return HealthCategory(Health(thing).Amount);
    } else if (thing is "HealthPickup") {
      return HealthCategory(HealthPickup(thing).Health);
    } else if (thing is "Ammo") {
      let a = Ammo(thing);
      return AmmoCategory(a.Amount, a.MaxAmount);
    } else if (IsTool(Inventory(thing))) {
      return "tool";
    }

    return "";
  }
}

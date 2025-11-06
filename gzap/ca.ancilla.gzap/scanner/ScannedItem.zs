// Holds information about a single scanned item.

#namespace GZAP;

#include "./ScannedLocation.zsc"
#debug off;

class ::ScannedItem : ::ScannedLocation {
  string category;
  string tag;
  bool secret;
  int hub;
  int tid;

  static ::ScannedItem Create(Actor thing) {
    let loc = ::ScannedItem(new("::ScannedItem"));
    // TODO: This is a bit misnamed at the moment, it's a hyphen-separated list
    // of categories.
    loc.category = ItemCategory(thing);
    loc.typename = thing.GetClassName();
    loc.tag = thing.GetTag();
    loc.secret = IsSecret(thing);
    loc.pos = thing.pos;
    loc.tid = thing.tid;

    if (loc.category == "key") {
      loc.hub = ::ScannedItem.GetHubClusterID(Inventory(thing));
    }

    let [newtype, ok] = ::RC.Get().GetTypename(loc.typename);
    if (ok) {
      class<Actor> cls = newtype;
      loc.typename = newtype;
      loc.tag = GetDefaultByType(cls).GetTag();
    }

    return loc;
  }

  // Returns the cluster ID for the hubcluster this item belongs to, if any, or
  // 0 if it isn't in a hubcluster/we don't care if it is.
  static int GetHubClusterID(Inventory thing) {
    if (!thing) return 0;
    DEBUG("GetHubClusterID: %s (amount: %d / is_hub: %d / cluster: %d)",
        thing.GetClassName(), thing.InterHubAmount, level.ClusterFlags & level.CLUSTER_HUB, level.cluster);
    if (level.ClusterFlags & level.CLUSTER_HUB == 0) return 0;
    return level.cluster;
  }

  override void Output(string mapname) {
    string secret_str = "";
    if (secret) {
      secret_str = string.format("\"secret\": %s, ", ::Util.bool2str(secret));
    }

    if (typename == "SecretTrigger") {
      ::Scanner.Output("SECRET", mapname, string.format("\"tid\": %d", self.tid));
      return;
    }

    ::Scanner.Output("ITEM", mapname, string.format(
        "\"category\": \"%s\", \"typename\": \"%s\", \"tag\": \"%s\", %s%s%s",
        category, typename, tag, secret_str, OutputSkill(), OutputPosition()));

    if (self.category == "key") {
      OutputKeyInfo(mapname);
    }
  }

  void GetMapsForKey(string mapname, Array<string> maps) {
    maps.Clear();
    if (self.hub == 0) {
      maps.Push(mapname);
      return;
    }

    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      if (info.cluster != self.hub) continue;
      maps.Push(info.mapname);
    }
  }

  void OutputKeyInfo(string mapname) {
    if (self.hub > 0) {
      OutputHubKeyInfo(mapname);
      return;
    }

    ::Scanner.Output("KEY", mapname, string.format(
      "\"tag\": \"%s\", \"typename\": \"%s\", \"scopename\": \"%s\", \"cluster\": %d, \"maps\": [\"%s\"]",
      self.tag, self.typename, mapname, self.hub, mapname));
  }

  void OutputHubKeyInfo(string mapname) {
    int maps;
    string map_str = "";

    Array<string> maplist;
    GetMapsForKey(mapname, maplist);
    foreach (lump : maplist) {
      ++maps;
      map_str = string.format("%s%s\"%s\"",
        map_str, map_str == "" ? "" : ", ", lump);
    }

    DEBUG("OutputKeyInfo: maps: %d / map_str: %s", maps, map_str);

    let scopename = ::RC.Get().GetNameForCluster(self.hub);
    ::Scanner.Output("KEY", mapname, string.format(
        "\"tag\": \"%s\", \"typename\": \"%s\", \"scopename\": \"%s\", \"cluster\": %d, \"maps\": [%s]",
        self.tag, self.typename, scopename, self.hub, map_str));
  }

  static bool IsSecret(Actor thing) {
    return (thing.cursector.IsSecret() || thing.cursector.WasSecret() || thing is "SecretTrigger");
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
      return "powerup-maprevealer";
    } else if (thing is "SecretTrigger") {
      return "secret-marker";
    } else if (thing is "PowerupGiver") {
      if (IsTool(Inventory(thing))) {
        return "powerup-tool";
      } else {
        return "powerup";
      }
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

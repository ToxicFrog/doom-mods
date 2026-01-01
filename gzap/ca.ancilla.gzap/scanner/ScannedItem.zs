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

  static ::ScannedItem Create(Actor thing, string mapname) {
    let loc = ::ScannedItem(new("::ScannedItem"));
    // TODO: This is a bit misnamed at the moment, it's a hyphen-separated list
    // of categories.
    loc.category = ItemCategory(thing);
    loc.typename = thing.GetClassName();
    loc.tag = thing.GetTag();
    loc.secret = IsSecret(thing);
    loc.pos = thing.pos;
    loc.tid = thing.tid;
    loc.mapname = mapname;

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

  override void Output() {
    // HACK HACK HACK
    // If the category is .replaceonly, do not emit it into the logic file,
    // but since it has a non-empty category, it can still be replaced at runtime.
    // This is currently only used for a hanging pot in E2M4 Faithless that in
    // normal play is scripted to drop a key when broken, so that the Check based
    // on that key replaces it.
    // We need a better way to handle this, like associating the location with a
    // specific actor type and allowing it to replace that even if the actor
    // would not normally be subject to scanning; at present, since the hanging
    // pot is not Inventory, it does not get considered as a replacement target
    // without this.
    if (self.category == "" || self.category == ".replaceonly") {
      return;
    }

    string secret_str = "";
    if (secret) {
      secret_str = string.format("\"secret\": %s, ", ::Util.bool2str(secret));
    }

    if (typename == "SecretTrigger") {
      ::Scanner.Output("SECRET", string.format(
          "\"pos\": [\"%s\",\"secret\",\"tid\",%d]", mapname, self.tid));
      return;
    }

    string tid_str = "";
    if (self.tid) {
      tid_str = string.format("\"tid\": %d, ", self.tid);
    }

    ::Scanner.Output("ITEM", string.format(
      "\"category\": \"%s\", \"typename\": \"%s\", \"tag\": \"%s\", %s%s%s%s",
      category, typename, tag, secret_str, tid_str,
      OutputSkill(), OutputPosition()));

    if (self.category == "key") {
      OutputKeyInfo();
    }
  }

  void GetMapsForKey(Array<string> maps) {
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

  void OutputKeyInfo() {
    if (self.hub > 0) {
      OutputHubKeyInfo();
      return;
    }

    ::Scanner.Output("KEY", string.format(
      "\"tag\": \"%s\", \"typename\": \"%s\", \"scopename\": \"%s\", \"cluster\": %d, \"maps\": [\"%s\"]",
      self.tag, self.typename, mapname, self.hub, mapname));
  }

  void OutputHubKeyInfo() {
    int maps;
    string map_str = "";

    Array<string> maplist;
    GetMapsForKey(maplist);
    foreach (lump : maplist) {
      ++maps;
      map_str = string.format("%s%s\"%s\"",
        map_str, map_str == "" ? "" : ", ", lump);
    }

    DEBUG("OutputKeyInfo: maps: %d / map_str: %s", maps, map_str);

    let scopename = ::RC.Get().GetNameForCluster(self.hub);
    ::Scanner.Output("KEY", string.format(
        "\"tag\": \"%s\", \"typename\": \"%s\", \"scopename\": \"%s\", \"cluster\": %d, \"maps\": [%s]",
        self.tag, self.typename, scopename, self.hub, map_str));
  }

  static bool IsSecret(Actor thing) {
    return (thing.cursector.IsSecret() || thing.cursector.WasSecret() || thing is "SecretTrigger");
  }

  static bool IsTool(readonly<Inventory> thing) {
    if (!thing) return false;
    return thing.bINVBAR && !thing.bAUTOACTIVATE;
  }

  static string HealthSize(int amount) {
    if (amount >= 100) return "big";
    if (amount >= 25) return "medium";
    return "small";
  }

  static string ArmourSize(int amount) {
    if (amount >= 100) return "big";
    if (amount >= 25) return "medium";
    return "small";
  }

  static string AmmoSize(int amount, int maxamount) {
    if (amount >= maxamount/5) return "medium";
    return "small";
  }

  // TODO: we can use inventory flags for this better than class hierarchy in many cases.
  // .BIGPOWERUP - item is particularly powerful
  // .HUBPOWER, .PERSISTENTPOWER, and .InterHubAmount allow carrying between levels
  // .COUNTITEM - counts towards the % items collected stat
  // there's also sv_unlimited_pickup to remove all limits on ammo capacity(!)
  static string ItemCategory(readonly<Actor> thing) {
    // Categories set in GZAPRC take precedence over everything else.
    let [category, ok] = ::RC.Get().GetCategory(thing.GetClassName());
    if (ok) return category;

    // Hardcoded categories or category sets.
    // TODO: if we can get GZAPRC to check any-subclass-of rather than exact
    // class matches, we can move a lot of this into GZAPRC.
    if (thing is "Key" || thing is "PuzzleItem") {
      return "key";
    } else if (thing is "Weapon" || thing is "WeaponPiece") {
      return "weapon";
    } else if (thing is "BackpackItem") {
      return "big-ammo";
    } else if (thing is "MapRevealer") {
      return "powerup-maprevealer";
    } else if (thing is "SecretTrigger") {
      return "secret-marker";
    }

    readonly<Inventory> inv = Inventory(thing);
    if (!inv) { return ""; }

    // Composite categories.
    Array<string> categories;

    // Things that restore health.
    if (inv is "Health") {
      categories.Push(HealthSize(Health(inv).Amount));
      categories.Push("health");
    } else if (inv is "HealthPickup") {
      categories.Push(HealthSize(HealthPickup(inv).Health));
      categories.Push("health");
    } else if (inv.bISHEALTH) {
      categories.Push("health");
    }

    // Things that restore armour.
    if (inv is "BasicArmorPickup") {
      categories.Push(ArmourSize(BasicArmorPickup(inv).SaveAmount));
      categories.push("armor");
    } else if (inv is "BasicArmorBonus") {
      categories.Push(ArmourSize(BasicArmorBonus(inv).SaveAmount));
      categories.push("armor");
    } else if (inv.bISARMOR) {
      categories.push("armor");
    }

    // Things that restore ammunition.
    if (inv is "Ammo") {
      let a = Ammo(inv);
      categories.Push(AmmoSize(a.Amount, a.MaxAmount));
      categories.Push("ammo");
    }

    // Buffs and whatnot.
    if (inv is "PowerupGiver") {
      categories.Push("powerup");
    }

    // Things that can be picked up and carried around and used later.
    if (IsTool(inv)) {
      categories.Push("tool");
    }

    return ::Util.join("-", categories);
  }
}

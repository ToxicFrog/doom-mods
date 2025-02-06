// Archipelago state about a single map.
//
// From the data package, we get knowledge of the map itself, which keys it
// needs, and which checks it contains.
//
// From the journal, we get information about whether the player has access to
// the level at all, whether they have the automap, whether they've completed
// the level, which keys they have, and which checks they've emptied.

#namespace GZAP;
#debug on;

// Information about a single check.
class ::CheckInfo {
  uint apid;
  string name;
  bool progression;
  bool checked;
  Vector3 pos; float angle;

  bool Eq(Vector3 pos, float angle) {
    return self.pos == pos && self.angle == angle;
  }
}

// Information about the map as a whole. Needs to be playsim scoped so that we
// can insert keys into the player's inventory.
// TODO: should we hoist that into the PlayEventHandler and keep this data-scoped?
class ::PerMapInfo play {
  Array<::CheckInfo> checks;
  Map<string, bool> keys;
  bool access;
  bool automap;
  bool cleared;

  static ::PerMapInfo Create(string key, bool access, bool automap, bool cleared) {
    let info = ::PerMapInfo(new("::PerMapInfo"));
    if (key != "") info.keys.Insert(key, true);
    info.access = access;
    info.automap = automap;
    info.cleared = cleared;
    return info;
  }

  void RegisterCheck(uint apid, string name, bool progression, Vector3 pos, float angle) {
    let info = ::CheckInfo(new("::CheckInfo"));
    info.apid = apid;
    info.name = name;
    info.progression = progression;
    info.checked = false;
    info.pos = pos; info.angle = angle;
    checks.push(info);
  }

  ::CheckInfo FindCheck(Vector3 pos, float angle) {
    foreach (info : checks) {
      if (info.Eq(pos, angle)) return info;
    }
    return null;
  }

  uint ChecksFound() const {
    uint found = 0;
    foreach (check : checks) {
      if (check.checked) ++found;
    }
    return found;
  }

  uint ChecksTotal() const {
    return checks.Size();
  }

  void RegisterKey(string key) {
    keys.Insert(key, false);
  }

  void AddKey(string key) {
    keys.Insert(key, true);
  }

  bool HasKey(string key) const {
    return keys.GetIfExists(key);
  }

  uint KeysFound() const {
    uint found = 0;
    foreach (_, v : keys) {
      if (v) ++found;
    }
    return found;
  }

  uint KeysTotal() const {
    return keys.CountUsed();
  }

  void UpdateInventory(PlayerPawn mo) {
    if (automap) {
      mo.GiveInventoryType("MapRevealer");
    }

    foreach (key, val : keys) {
      if (val) {
        mo.GiveInventoryType(key);
      } else {
        mo.TakeInventory(key, 999);
      }
    }
  }
}

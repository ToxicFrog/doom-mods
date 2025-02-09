// Information about an entire map, modeled in AP as a Region.
//
// This contains not just the set of Locations in the region, but also per-level
// flags like whether the player has access to it at all and what keys they have
// for it.
//
// It's responsible for synchronizing the player's inventory when they enter the
// level, and contains some utility functions for managing the Locations inside
// it.
#namespace GZAP;

#include "./Location.zsc"

class ::Region play {
  string map;
  Array<::Location> checks;
  Map<string, bool> keys;
  bool access;
  bool automap;
  bool cleared;
  uint exit_id;

  static ::Region Create(string map, uint exit_id) {
    let info = ::Region(new("::Region"));
    info.map = map;
    info.exit_id = exit_id;
    return info;
  }

  static ::Region CreatePartial(string map, string key, bool access, bool automap, bool cleared) {
    let info = ::Region(new("::Region"));
    info.map = map;
    if (key != "") info.keys.Insert(key, true);
    info.access = access;
    info.automap = automap;
    info.cleared = cleared;
    return info;
  }

  void RegisterCheck(uint apid, string name, bool progression, Vector3 pos, float angle) {
    let info = ::Location(new("::Location"));
    info.apid = apid;
    info.name = name;
    info.progression = progression;
    info.checked = false;
    info.pos = pos; info.angle = angle;
    checks.push(info);
  }

  ::Location FindCheck(Vector3 pos, float angle) {
    foreach (info : checks) {
      // console.printf("Check.Eq? (%d, %d, %d, %d) == (%d, %d, %d, %d)",
      //   pos.x, pos.y, pos.z, angle,
      //   info.pos.x, info.pos.y, info.pos.z, info.angle);
      if (info.Eq(pos, angle)) return info;
    }
    return null;
  }

  void ClearCheck(uint apid) {
    foreach (info: checks) {
      if (info.apid == apid) {
        info.checked = true;
        return;
      }
    }
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

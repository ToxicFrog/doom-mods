// Classes for keeping track of checks, populated by the data package.
//
// A CheckInfo just contains information about a single check: its location
// and categorization. A CheckList contains multiple CheckInfos and utility
// functions for querying it.

#namespace GZAP;

class ::CheckInfo play {
  uint apid;
  string name;
  bool progression;
  Vector3 pos; float angle;

  bool Eq(Vector3 pos, float angle) {
    return self.pos == pos && self.angle == angle;
  }
}

class ::CheckList play {
  Array<::CheckInfo> checks;

  void AddCheck(uint apid, string name, bool progression, Vector3 pos, float angle) {
    let info = ::CheckInfo(new("::CheckInfo"));
    info.apid = apid;
    info.name = name;
    info.progression = progression;
    info.pos = pos; info.angle = angle;
    checks.push(info);
  }

  ::CheckInfo FindCheck(Vector3 pos, float angle) {
    foreach (info : checks) {
      if (info.Eq(pos, angle)) return info;
    }
    return null;
  }
}

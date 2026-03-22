// A map subregion. Defined using the in-game logic editor, a subregion belongs
// to a specific map and has a list of prerequisites which may be keys, weapons,
// items, other maps or subregions, etc.
//
// A subregion also has a name, which is used to name the locations within it.

#namespace GZAP;
#debug off;

class ::Subregion play {
  string map;
  string name;
  Map<string, bool> prereqs;

  static ::Subregion Create(string name, ::Region region) {
    let subregion = new("::Subregion");
    subregion.map = region.map;
    subregion.name = name;
    subregion.FillStartingPrereqs(region);
    region.subregions.Insert(name, subregion);
    region.subregion_names.Push(name);
    return subregion;
  }

  void FillStartingPrereqs(::Region region) {
    let apstate = ::PlayEventHandler.GetState();
    foreach (k, v : apstate.GetCurrentRegion().keys) {
      if (v.held && v.enabled) {
        self.prereqs.Insert("key/" .. v.typename, true);
      }
    }
    // Also insert a dependency on the currently active subregion, if any.
    if (apstate.subregion) {
      self.prereqs.Insert("map/"..apstate.subregion.map.."/"..apstate.subregion.name, true);
    }
  }

  bool HasPrereq(string prereq) const {
    return self.prereqs.CheckKey(prereq);
  }

  void TogglePrereq(string prereq) {
    if (self.HasPrereq(prereq)) {
      self.prereqs.Remove(prereq);
    } else {
      self.prereqs.Insert(prereq, true);
    }
  }

  string PrereqsAsString() const {
    string buf = "";
    foreach (k,v : self.prereqs) {
      if (HasPrereq("key/*") && k != "key/*" && k.Left(4) == "key/") continue;
      buf.AppendFormat("%s%s", buf ? " ∧ " : "", k);
    }
    return buf;
  }

  void Output() {
    Array<string> prereq_list;
    foreach (k,v : self.prereqs) prereq_list.Push(k);
    ::IPC.DefineRegion(self.map, self.name, prereq_list);
  }
}

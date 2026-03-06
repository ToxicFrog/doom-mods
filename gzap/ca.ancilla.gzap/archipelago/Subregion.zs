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
    return subregion;
  }

  void FillStartingPrereqs(::Region region) {
    foreach (k, v : ::PlayEventHandler.GetState().GetCurrentRegion().keys) {
      if (v.held && v.enabled) {
        self.prereqs.Insert("key/" .. v.typename, true);
      }
    }
  }

  void Output() {
    Array<string> prereq_list;
    foreach (k,v : self.prereqs) prereq_list.Push(k);
    ::IPC.DefineRegion(self.map, self.name, prereq_list);
  }
}

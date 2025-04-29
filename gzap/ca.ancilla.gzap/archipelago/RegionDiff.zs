// Information about changes to be applied to a map.
// This is used internally to model the "items" that grant keys and suchlike.
#namespace GZAP;

#include "./Location.zsc"

class ::RegionDiff play {
  string map;
  string key;
  bool access;
  bool automap;
  bool cleared;

  private static ::RegionDiff CreateEmpty(string map) {
    let diff = ::RegionDiff(new("::RegionDiff"));
    diff.map = map;
    return diff;
  }

  static ::RegionDiff CreateKey(string map, string key) {
    let diff = ::RegionDiff.CreateEmpty(map);
    diff.key = key;
    return diff;
  }

  static ::RegionDiff CreateFlags(string map, bool access, bool automap, bool cleared) {
    let diff = ::RegionDiff.CreateEmpty(map);
    diff.access = access;
    diff.automap = automap;
    diff.cleared = cleared;
    return diff;
  }

  void Apply(::Region region) {
    let maptitle = LevelInfo.FindLevelInfo(self.map).LookupLevelName();

    if (self.access && !region.access) {
      ::Util.announce("$GZAP_GOT_ACCESS", maptitle, self.map);
      region.access = true;
    }
    if (self.automap && !region.automap) {
      ::Util.announce("$GZAP_GOT_AUTOMAP", maptitle, self.map);
      region.automap = true;
    }
    if (self.cleared && !region.cleared) {
      ::Util.announce("$GZAP_LEVEL_DONE", maptitle, self.map);
      region.cleared = true;
    }
  }
}


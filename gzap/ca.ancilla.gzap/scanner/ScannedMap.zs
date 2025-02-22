// Holds information about a scanned map, including its MAPINFO and all of its
// Locations.

#namespace GZAP;

#include "./ScannedLocation.zsc"
#include "./ScannedItem.zsc"

class ::ScannedMap play {
  string name;
  LevelInfo info;
  Array<::ScannedLocation> locations;
  // Highest skill we've completed a scan on.
  // We don't track 0 (ITYTD) or 4 (NM) because they have the same actor placement
  // as 1 and 3, so 0 means we have scanned nothing and 3 means we've scanned
  // all the skill levels we care about.
  int max_skill;
  bool done;

  static ::ScannedMap Create(string mapname) {
    let sm = ::ScannedMap(new("::ScannedMap"));
    sm.name = mapname;
    sm.info = LevelInfo.FindLevelInfo(mapname);
    sm.done = false;
    sm.max_skill = 0;
    return sm;
  }

  void Output() {
    ::Scanner.Output("MAP", name, string.format("\"checksum\": \"%s\", \"info\": %s",
      LevelInfo.MapChecksum(name), GetMapinfoJSON()));
    foreach (loc : locations) {
      loc.Output(name);
    }
  }

  void MarkDone() {
    self.max_skill = ::Util.GetSkill();
  }

  bool IsScanned() {
    return self.max_skill == 3;
  }

  bool IsCurrentLevel() {
    return name == level.mapname.MakeUpper() && self.max_skill+1 == ::Util.GetSkill();
  }

  int NextSkill() {
    return self.max_skill+1;
  }

  // Add a location to the map associated with the current difficulty.
  // If the same location was already recorded on a different difficulty, this
  // just adds the current difficulty to it.
  void AddLocation(::ScannedLocation newloc) {
    // See if there's an existing location we should merge this one with.
    // A location qualifies for merge if it has the same position and typename,
    // but does not have the current difficulty bit set.
    foreach (loc : locations) {
      if (loc.pos != newloc.pos) continue;
      if (loc.typename != newloc.typename) continue;
      if (loc.HasSkill(::Util.GetSkill())) continue;
      loc.AddSkill(::Util.GetSkill());
      return;
    }
    newloc.AddSkill(::Util.GetSkill());
    locations.Push(newloc);
  }

  string GetMapinfoJSON() {
    let flags = GetFlagsForMapinfo(info);
    return string.format(
        "{ "
        "\"levelnum\": %d, \"title\": \"%s\", \"is_lookup\": %s, "
        "\"sky1\": \"%s\", \"sky1speed\": \"%f\", "
        "\"sky2\": \"%s\", \"sky2speed\": \"%f\", "
        "\"music\": \"%s\", \"music_track\": \"%d\", "
        "\"cluster\": %d, \"flags\": [%s] }",
        info.LevelNum, info.LevelName,
        ::Util.bool2str(info.flags & LEVEL_LOOKUPLEVELNAME),
        info.SkyPic1, info.SkySpeed1,
        info.SkyPic2, info.SkySpeed2,
        info.Music, info.MusicOrder,
        info.Cluster, flags);
  }

  string GetFlagsForMapinfo(LevelInfo info) {
    string flags = "";
    flags = AddFlag(flags, info.flags, LEVEL_DOUBLESKY, "doublesky");
    flags = AddFlag(flags, info.flags2, LEVEL2_INFINITE_FLIGHT, "infiniteflightpowerup");
    // Special action effects
    // specialaction_exitlevel just clears the other special flags, so we don't
    // need it; we get it just by not writing a specialaction_ flag.
    flags = AddFlag(flags, info.flags, LEVEL_SPECKILLMONSTERS, "specialaction_killmonsters");
    flags = AddFlag(flags, info.flags, LEVEL_SPECLOWERFLOOR, "specialaction_lowerfloor");
    flags = AddFlag(flags, info.flags, LEVEL_SPECLOWERFLOORTOHIGHEST, "specialaction_lowerfloortohighest");
    flags = AddFlag(flags, info.flags, LEVEL_SPECOPENDOOR, "specialaction_opendoor");
    // Special action triggers
    flags = AddFlag(flags, info.flags, LEVEL_MAP07SPECIAL, "map07special");
    flags = AddFlag(flags, info.flags, LEVEL_BRUISERSPECIAL, "baronspecial");
    flags = AddFlag(flags, info.flags, LEVEL_CYBORGSPECIAL, "cyberdemonspecial");
    flags = AddFlag(flags, info.flags, LEVEL_SPIDERSPECIAL, "spidermastermindspecial");
    flags = AddFlag(flags, info.flags, LEVEL_HEADSPECIAL, "ironlichspecial");
    flags = AddFlag(flags, info.flags, LEVEL_MINOTAURSPECIAL, "minotaurspecial");
    flags = AddFlag(flags, info.flags, LEVEL_SORCERER2SPECIAL, "dsparilspecial");
    flags = AddFlag(flags, info.flags3, LEVEL3_E1M8SPECIAL, "e1m8special");
    flags = AddFlag(flags, info.flags3, LEVEL3_E2M8SPECIAL, "e2m8special");
    flags = AddFlag(flags, info.flags3, LEVEL3_E3M8SPECIAL, "e3m8special");
    flags = AddFlag(flags, info.flags3, LEVEL3_E4M8SPECIAL, "e4m8special");
    flags = AddFlag(flags, info.flags3, LEVEL3_E4M6SPECIAL, "e4m6special");
    return flags;
  }

  string AddFlag(string buf, uint flags, uint flag, string flagname) {
    if ((flags & flag) == flag) {
      return string.format("%s%s\"%s\"", buf, buf == "" ? "" : ", ", flagname);
    }
    return buf;
  }
}

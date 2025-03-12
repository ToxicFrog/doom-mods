// Holds information about a scanned map, including its MAPINFO and all of its
// Locations.

#namespace GZAP;

#include "./ScannedLocation.zsc"
#include "./ScannedItem.zsc"

class ::ScannedMap play {
  string name;
  LevelInfo info;
  // Computed rank/sphere of level based on "distance" from initial mapset.
  // TODO: ideally, we'd like to have both "rank" (how far into the game the level is)
  // and "difficulty" (based on enemy heuristics, probably) so that both can be
  // used for balancing.
  uint rank;
  Array<::ScannedLocation> locations;
  // Highest skill we've completed a scan on.
  // We don't track 0 (ITYTD) or 4 (NM) because they have the same actor placement
  // as 1 and 3, so 0 means we have scanned nothing and 3 means we've scanned
  // all the skill levels we care about.
  int max_skill;
  bool done;

  static ::ScannedMap Create(string mapname, uint rank) {
    let sm = ::ScannedMap(new("::ScannedMap"));
    sm.name = mapname;
    sm.info = LevelInfo.FindLevelInfo(mapname);
    sm.done = false;
    sm.max_skill = 0;
    sm.rank = rank;
    return sm;
  }

  void Output() {
    ::Scanner.Output("MAP", name, string.format(
      "\"checksum\": \"%s\", \"rank\": %d, \"info\": %s",
      LevelInfo.MapChecksum(name), self.rank, GetMapinfoJSON()));
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
    flags = AddFlag(flags, info.flags, LEVEL_USEPLAYERSTARTZ, "useplayerstartz");
    // TODO: if a level has infiniteflightpowerup, we should require wings of wrath
    // in the logic, and make sure the player always has one when entering the level
    // if they've found it.
    flags = AddFlag(flags, info.flags2, LEVEL2_INFINITE_FLIGHT, "infiniteflightpowerup");
    // Special action effects
    // specialaction_exitlevel just clears the other special flags, so we don't
    // need it; we get it just by not writing a specialaction_ flag.
    flags = AddFlag(flags, info.flags, LEVEL_SPECKILLMONSTERS, "specialaction_killmonsters");
    flags = AddFlag(flags, info.flags, LEVEL_SPECLOWERFLOOR, "specialaction_lowerfloor");
    flags = AddFlag(flags, info.flags, LEVEL_SPECLOWERFLOORTOHIGHEST, "specialaction_lowerfloortohighest");
    flags = AddFlag(flags, info.flags, LEVEL_SPECOPENDOOR, "specialaction_opendoor");
    flags = AddFlag(flags, info.flags, LEVEL_MONSTERSTELEFRAG, "allowmonstertelefrags");
    // Special action triggers
    flags = AddFlag(flags, info.flags, LEVEL_BRUISERSPECIAL, "baronspecial");
    flags = AddFlag(flags, info.flags, LEVEL_CYBORGSPECIAL, "cyberdemonspecial");
    flags = AddFlag(flags, info.flags, LEVEL_HEADSPECIAL, "ironlichspecial");
    flags = AddFlag(flags, info.flags, LEVEL_MAP07SPECIAL, "map07special");
    flags = AddFlag(flags, info.flags, LEVEL_MINOTAURSPECIAL, "minotaurspecial");
    flags = AddFlag(flags, info.flags, LEVEL_SORCERER2SPECIAL, "dsparilspecial");
    flags = AddFlag(flags, info.flags, LEVEL_SPIDERSPECIAL, "spidermastermindspecial");
    flags = AddFlag(flags, info.flags3, LEVEL3_E1M8SPECIAL, "e1m8special");
    flags = AddFlag(flags, info.flags3, LEVEL3_E2M8SPECIAL, "e2m8special");
    flags = AddFlag(flags, info.flags3, LEVEL3_E3M8SPECIAL, "e3m8special");
    flags = AddFlag(flags, info.flags3, LEVEL3_E4M8SPECIAL, "e4m8special");
    flags = AddFlag(flags, info.flags3, LEVEL3_E4M6SPECIAL, "e4m6special");
    // Compatibility flags
    // Note that compat flags are stored in two places: LevelInfo and LevelLocals.
    // The former stores the flags as specified in MAPINFO. The latter stores the
    // flags as actually applied, which combines the MAPINFO flags with ones
    // hardcoded into gzdoom and settings from IWADINFO.
    // The latter two are applied at runtime regardless, so we only care about
    // the MAPINFO flags here.
    flags = AddFlag(flags, info.compatflags, COMPATF_ANYBOSSDEATH, "compat_anybossdeath");
    flags = AddFlag(flags, info.compatflags, COMPATF_BOOMSCROLL, "compat_boomscroll");
    flags = AddFlag(flags, info.compatflags, COMPATF_LIGHT, "compat_lightlevel");
    flags = AddFlag(flags, info.compatflags, COMPATF_LIMITPAIN, "compat_limitpain");
    flags = AddFlag(flags, info.compatflags, COMPATF_RAVENSCROLL, "compat_ravenscroll");
    flags = AddFlag(flags, info.compatflags, COMPATF_SECTORSOUNDS, "compat_sectorsounds");
    flags = AddFlag(flags, info.compatflags, COMPATF_SOUNDTARGET, "compat_soundtarget");
    flags = AddFlag(flags, info.compatflags, COMPATF_STAIRINDEX, "compat_stairs");
    flags = AddFlag(flags, info.compatflags, COMPATF_USEBLOCKING, "compat_useblocking");
    flags = AddFlag(flags, info.compatflags2, COMPATF2_CHECKSWITCHRANGE, "compat_checkswitchrange");
    flags = AddFlag(flags, info.compatflags2, COMPATF2_FLOORMOVE, "compat_floormove");
    flags = AddFlag(flags, info.compatflags2, COMPATF2_NOMBF21, "compat_nombf21");
    flags = AddFlag(flags, info.compatflags2, COMPATF2_PUSHWINDOW, "compat_disablepushwindowcheck");
    flags = AddFlag(flags, info.compatflags2, COMPATF2_TELEPORT, "compat_teleport");
    return flags;
  }

  string AddFlag(string buf, uint flags, uint flag, string flagname) {
    if ((flags & flag) == flag) {
      return string.format("%s%s\"%s\"", buf, buf == "" ? "" : ", ", flagname);
    }
    return buf;
  }
}

// Holds information about a scanned map, including its MAPINFO and all of its
// Locations.

#namespace GZAP;
#debug off;

#include "./ScannedLocation.zsc"
#include "./ScannedItem.zsc"

class ::ScannedMap play {
  string name;
  LevelInfo info;
  // User-facing names, after localization table resolution etc is performed.
  // levelname and clustername come from LevelLocals. episodename comes from
  // EpisodeInfo and is inherited from previous maps, since EpisodeInfo only
  // associates the episode with its first map.
  string levelname;
  string episodename;
  string clustername;
  // Computed rank/sphere of level based on "distance" from initial mapset.
  // TODO: ideally, we'd like to have both "rank" (how far into the game the level is)
  // and "difficulty" (based on enemy heuristics, probably) so that both can be
  // used for balancing.
  uint rank;
  Array<::ScannedLocation> locations;
  Array<int> secrets;
  // Actors broken down by type.
  int monster_count;
  Map<string, int> actors;
  // Highest skill we've completed a scan on.
  // The scanner uses this to find the next skill that will produce a different
  // spawn filter and thus a productive scan.
  int last_skill;
  // Bitmask of spawn filters we've examined.
  uint filters;
  // Set if this map should be used for exit searching but not included in the
  // logic file.
  bool skip;
  // Set if this map should be ignored entirely.
  bool prune;
  // Cluster ID iff this map belongs to a hubcluster. Else 0.
  int hub;

  static ::ScannedMap Create(string mapname, ::ScannedMap prev) {
    let sm = ::ScannedMap(new("::ScannedMap"));
    sm.name = mapname;
    sm.info = LevelInfo.FindLevelInfo(mapname);
    sm.last_skill = -1;
    sm.rank = prev ? prev.rank+1 : 0;
    sm.hub = 0;
    // We can't actually use this, because AllEpisodes is not in any released
    // version of uzdoom.
    // foreach (e : AllEpisodes) {
    //   if (e.mEpisodeMap.MakeUpper() == sm.name) {
    //     sm.episodename = e.mEpisodeName;
    //   } else if (prev) {
    //     sm.episodename = prev.episodename;
    //   } else {
    //     sm.episodename = "";
    //   }
    // }
    sm.episodename = "";
    return sm;
  }

  void Output(int spawn_filter) {
    DEBUG("ScannedMap::Output: skip=%d, locs=%d", self.skip, self.locations.Size());
    if (self.skip || self.prune) return;
    // Do not include maps with nothing to randomize.
    if (locations.Size() == 0) return;
    // In Wolf3d TC, failing to do this will result in garbage at the start of
    // the AP-MAP line. This only happens when scanning, but also only happens
    // when wolf3d.ipk3 is loaded for some reason. We include this to put the
    // garbage on a previous line and hopefully work around this in other (i)wads
    // that may have similar issues.
    console.printfEX(PRINT_LOG, "");

    let titles = string.format(" \"levelname\": \"%s\",", self.levelname);
    if (self.episodename != "") {
      titles.AppendFormat(" \"episodename\": \"%s\",", self.episodename);
    }
    if (self.clustername != "") {
      titles.AppendFormat(" \"clustername\": \"%s\",", self.clustername);
    }
    DEBUG("scanned map titles, level=%s episode=%s cluster=%s", self.levelname, self.episodename, self.clustername);

    ::Scanner.Output("MAP", string.format(
      "\n  \"map\": \"%s\",%s\n"
      "  \"checksum\": \"%s\", \"rank\": %d, \"monster_count\": %d,\n"
      "  \"info\": %s,\n"
      "  \"monsters\": { %s },\n"
      "  \"prereqs\": [ %s ]\n",
      name, titles,
      LevelInfo.MapChecksum(name), self.rank, self.monster_count,
      GetMapinfoJSON(),
      GetMonsterCountJSON(),
      GetPrereqs()));

    foreach (loc : locations) {
      loc.Output(spawn_filter);
    }

    foreach (sector : secrets) {
      ::Scanner.Output("SECRET", string.format(
        "\"pos\": [\"%s\",\"secret\",\"sector\",%d]", name, sector));
    }
  }

  // Called at the end of each scanning pass (i.e. once per skill level scanned).
  void FinalizeSkill() {
    self.filters = self.filters | ::Util.GetSpawnFilter();
    self.last_skill = ::Util.GetSkill();
  }

  bool IsMonster(class<Actor> cls) {
    let thing = GetDefaultByType(cls);
    return thing.bISMONSTER && !thing.bCORPSE;
  }

  void CopyFromLevelLocals(LevelLocals level) {
    self.levelname = level.LevelName;

    foreach (sector : level.sectors) {
      if (sector.IsSecret()) {
        self.secrets.Push(sector.Index());
      }
    }

    foreach (Actor thing : ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT)) {
      if (thing.bISMONSTER && !thing.bCORPSE) self.monster_count++;
      let count = self.actors.GetIfExists(thing.GetClassName());
      self.actors.Insert(thing.GetClassName(), count+1);
    }

    if (level.clusterflags & level.CLUSTER_HUB) {
      self.hub = level.cluster;
    }

    // self.episodename is set at construction time because it has to be inherited
    // from the parent map, we can't trust the one in LevelLocals
    self.clustername = ::RC.Get().GetNameForCluster(self.hub);
    DEBUG("clustername from RC: %s", self.clustername);
    if (self.clustername == "") {
      self.clustername = level.GetClusterName();
      DEBUG("clustername from mapinfo: %s", self.clustername);
    }
  }

  // Add a location to the map associated with the current difficulty.
  // If the same location was already recorded on a different difficulty, this
  // just adds the current difficulty to it.
  void AddLocation(::ScannedLocation newloc) {
    // See if there's an existing location we should merge this one with.
    // A location qualifies for merge if it has the same position and typename.
    foreach (loc : locations) {
      if (!::Location.IsCloseEnough(loc.pos, newloc.pos)) continue;
      if (loc.typename != newloc.typename) continue;
      loc.AddSkill(::Util.GetSpawnFilter());
      return;
    }
    newloc.AddSkill(::Util.GetSpawnFilter());
    locations.Push(newloc);
  }

  string GetMapinfoJSON() {
    let flags = GetFlagsForMapinfo(info);
    // Apparently it is legal to have a level title with embedded newlines.
    // While we're here, let's handle embedded quotes as well.
    let title = info.LevelName;
    title.Replace("\n", "\\n");
    title.Replace("\"", "\\\"");
    return string.format(
        "{ "
        "\"levelnum\": %d, \"title\": \"%s\", \"is_lookup\": %s, "
        "\"sky1\": \"%s\", \"sky1speed\": \"%f\", "
        "\"sky2\": \"%s\", \"sky2speed\": \"%f\", "
        "\"music\": \"%s\", \"music_track\": \"%d\", "
        "\"cluster\": %d, \"flags\": [%s] }",
        info.LevelNum, title,
        ::Util.bool2str(info.flags & LEVEL_LOOKUPLEVELNAME),
        info.SkyPic1, info.SkySpeed1,
        info.SkyPic2, info.SkySpeed2,
        info.Music, info.MusicOrder,
        self.hub, flags);
  }

  string GetFlagsForMapinfo(LevelInfo info) {
    string flags = "";
    flags = AddFlag(flags, info.flags, LEVEL_DOUBLESKY, "doublesky");
    flags = AddFlag(flags, info.flags, LEVEL_USEPLAYERSTARTZ, "useplayerstartz");
    flags = AddFlag(flags, info.flags, LEVEL_MONSTERSTELEFRAG, "allowmonstertelefrags");
    // TODO: if a level has infiniteflightpowerup, we should require wings of wrath
    // in the logic, and make sure the player always has one when entering the level
    // if they've found it.
    flags = AddFlag(flags, info.flags2, LEVEL2_INFINITE_FLIGHT, "infiniteflightpowerup");
    // Special action effects
    // specialaction_exitlevel just clears the other special flags, so we don't
    // need it; we get it just by not writing a specialaction_ flag.
    // specialaction_lowerfloor, specialaction_opendoor, and specialaction_lowerfloortohighest
    // get special handling -- the first two have separate bits, the last one is
    // denoted by setting both bits at once. >.<
    flags = AddFlag(flags, info.flags, LEVEL_SPECKILLMONSTERS, "specialaction_killmonsters");
    if (info.flags & LEVEL_SPECACTIONSMASK == LEVEL_SPECLOWERFLOORTOHIGHEST) {
      flags = AddFlag(flags, info.flags, LEVEL_SPECLOWERFLOORTOHIGHEST, "specialaction_lowerfloortohighest");
    } else {
      flags = AddFlag(flags, info.flags, LEVEL_SPECLOWERFLOOR, "specialaction_lowerfloor");
      flags = AddFlag(flags, info.flags, LEVEL_SPECOPENDOOR, "specialaction_opendoor");
    }
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
    // hardcoded into uzdoom and settings from IWADINFO.
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

  string GetMonsterCountJSON() {
    string buf = "";
    foreach (typename, count : self.actors) {
      if (!IsMonster(typename)) continue;
      buf.AppendFormat("%s\"%s\": %d", buf == "" ? "" : ", ", typename, count);
    }
    return buf;
  }

  string GetPrereqs() {
    let prereqs = ::RC.Get().GetPrereqsForMap(self.name, self.actors);
    if (prereqs.Size() == 0) return "";
    return string.format("\"%s\"", prereqs.Join("\", \""));
  }
}

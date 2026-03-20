// The actual scanning machinery.
// The ScanEventHandler just initializes one of these and then drives it based
// on netevents and level entry events.

#namespace GZAP;
#debug off;

#include "../actors/DehackedPickupProber.zsc"
#include "./ScannedMap.zsc"

class ::Scanner play {
  Array<::ScannedMap> queued;
  Map<string, ::ScannedMap> maps_by_name;
  Map<string, bool> skip;
  Map<string, bool> prune;
  // TODO: when the next version adds AddSkills to the globals we can do away
  // with all of this and just read that array.
  int target_skill; // Skill we expect ChangeLevel to place us at
  int max_skill; // Max skill level available
  uint all_filters;
  Array<int> filters_by_skill;

  static void Output(string type, string payload) {
    ::IPC.Send(type, string.format("{ %s }", payload));
  }

  void Init() {
    ::Util.printf("$GZAP_SCAN_STARTING");
    self.target_skill = 0;
    self.max_skill = -1;
    self.all_filters = 0;
    self.filters_by_skill.Clear();

    if (ap_scan_logic_flags == "") {
      // TODO: perhaps additional info here like wad name?
      ::IPC.Send("SCAN", "{ \"flags\": [] }");
    } else {
      string buf = ap_scan_logic_flags;
      buf.Replace(" ", "\", \"");
      ::IPC.Send("SCAN", string.format("{ \"flags\": [\"%s\"] }", buf));
    }
  }

  int QueueSize() {
    return self.queued.Size();
  }

  void SkipLevel(string mapname) {
    string mapname = mapname.MakeUpper();
    skip.Insert(mapname, true);
  }

  void PruneLevel(string mapname) {
    string mapname = mapname.MakeUpper();
    prune.Insert(mapname, true);
  }

  void ForceMapRank(string mapname, uint rank) {
    let sm = maps_by_name.GetIfExists(mapname.MakeUpper());
    if (!sm) return;
    sm.rank = rank;
  }

  bool EnqueueLevel(string mapname, ::ScannedMap prev) {
    string mapname = mapname.MakeUpper();

    if (!LevelInfo.MapExists(mapname)) {
      DEBUG("Skipping enqueue of %s because it doesn't exist.", mapname);
      return false;
    }

    if (maps_by_name.CheckKey(mapname)) {
      // Already enqueued or scanned, do nothing.
      DEBUG("Skipping enqueue of %s because it's already in the queue.", mapname);
      return false;
    }

    let sm = ::ScannedMap.Create(mapname, prev);
    sm.skip = self.skip.GetIfExists(mapname);
    sm.prune = self.prune.GetIfExists(mapname);

    maps_by_name.Insert(mapname, sm);
    queued.Push(sm);
    ::Util.printf("$GZAP_SCAN_MAP_ENQUEUED", sm.name);
    return true;
  }

  // Like EnqueueNext, but takes a cluster number and enqueues all maps in that
  // cluster at the given rank.
  void EnqueueCluster(int cluster, ::ScannedMap prev) {
    // We do this in reverse so that they get pushed into the front of the queue
    // in the same order they appear in the maplist, which makes the generated
    // logic a bit easier to navigate.
    for (int i = LevelInfo.GetLevelInfoCount()-1; i >= 0; --i) {
      let info = LevelInfo.GetLevelInfo(i);
      if (info.cluster != cluster) continue;
      DEBUG("Cluster scan found %s in cluster %d", info.mapname, cluster);
      EnqueueNext(info.mapname, prev);
    }
  }

  // Like EnqueueLevel, but places it at the head of the queue, immediately behind
  // the current level, rather than at the end.
  void EnqueueNext(string mapname, ::ScannedMap prev) {
    if (!EnqueueLevel(mapname, prev)) return;
    if (queued.Size() <= 2) return;
    // Grab the new map from the end of the queue
    let sm = queued[queued.Size()-1];
    // Move all entries except the first down one element (overwriting the one we
    // just grabbed)
    for (int i = queued.Size()-1; i > 1; --i) {
      queued[i] = queued[i-1];
    }
    // Schloop!
    queued[1] = sm;
  }

  bool MapFullyScanned(::ScannedMap map) {
    if (map.skip) {
      // A skipped map is considered done as soon as we've completed at least
      // one scanning pass on it and thus captured any exits from it.
      return map.filters > 0;
    } else if (self.max_skill < 0) {
      // Not done evaluating different skill levels yet.
      return false;
    }
    DEBUG("MapFullyScanned? %02X / %02X", map.filters, self.all_filters);
    return map.filters == self.all_filters;
  }

  // Return the next skill we should be scanning, that is to say, the lowest
  // skill greater than the current one that will introduce a new spawn filter.
  // This is a bit of a delicate dance. This is only called if MapFullyScanned()
  // returns false, which for all maps except the first means that there is at
  // least one skill that satisfies this requirement. On the first map, however,
  // we don't yet know how many skill levels or spawn filters are available.
  int NextSkill(::ScannedMap map) {
    if (self.max_skill < 0) {
      // Still determining what skill levels are available. Blindly assume that
      // the skill level one higher than the last one scanned is the next one.
      return map.last_skill+1;
    }

    // Find the lowest skill that adds a new filter to the bitmask.
    for (int i = map.last_skill+1; i < self.filters_by_skill.Size(); ++i) {
      if (self.filters_by_skill[i] & map.filters == 0) {
        return i;
      }
    }
    float f = 1; float g = 0; f = f/g; // die -- should never happen
    return -1;
  }

  // Initiate a scan of the next map in the queue.
  // Returns true if one was initiated (and calls level.ChangeLevel()), false if
  // there are no more maps left to scan.
  bool ScanNext() {
    while (queued.Size() > 0) {
      let nextmap = queued[0];
      if (nextmap.prune) {
        DEBUG("ScanNext: pruning %s", nextmap.name);
        queued.Delete(0);
        continue;
      }
      // If we're done scanning this map, output the results and move on to the next.
      if (MapFullyScanned(nextmap)) {
        DEBUG("Head map is done, moving on");
        ::Util.printf("$GZAP_SCAN_MAP_DONE", level.MapName);
        nextmap.Output(self.all_filters);
        queued.Delete(0);
        continue;
      }
      // Otherwise, we need to change to it and let the ScanEventHandler kick off
      // the scan. Note that we need to do this to change the skill level even
      // if is the same map we're currently on.
      self.target_skill = NextSkill(nextmap);
      DEBUG("Changing to %s at skill %d", nextmap.name, self.target_skill);
      if (level.ClusterFlags & level.CLUSTER_HUB) {
        // If it's a hubcluster level, blip us back to the GZAPHUB for a moment
        // to reset its state.
        level.ChangeLevel("GZAPHUB", 0, CHANGELEVEL_NOINTERMISSION, self.target_skill);
      }
      level.ChangeLevel(nextmap.name, 0, CHANGELEVEL_NOINTERMISSION, self.target_skill);
      return true;
    }
    // Queue is empty! We're done scanning for now.
    DEBUG("Queue empty");
    return false;
  }

  bool ScanDehacked(::ScannedMap nextmap, DehackedPickup thing) {
    DEBUG("DEH probe routine: %s [%s]", thing.GetTag(), thing.GetClassName());
    let prober = ::DehackedPickupProber(thing.Spawn("::DehackedPickupProber", thing.pos, NO_REPLACE));
    thing.CallTryPickup(prober);
    if (!prober.real_item) {
      prober.Destroy();
      return false;
    }
    nextmap.AddLocation(prober.real_item);
    prober.Destroy();
    return true;
  }

  // Finish scanning the current level.
  // This is called by the ScanEventHandler when it is done processing actors.
  // It is responsible for ingesting level information not related to actors,
  // and populating the queue with other levels reachable from this one.
  // Returns true if scanning is continuing, false otherwise.
  // Called once per pass, i.e. multiple times per map.
  bool FinalizeLevel(bool recurse, bool clusters) {
    DEBUG("FinalizeLevel: %d remaining", queued.Size());
    let nextmap = queued[0];

    DEBUG("filter=%d, all_filters=%02X, skill=%d", ::Util.GetSpawnFilter(), self.all_filters, ::Util.GetSkill());
    nextmap.FinalizeSkill();

    // Update information about skill levels and their corresponding spawn filters.
    if (self.target_skill > nextmap.last_skill) {
      // Did we find the last skill?
      DEBUG("Looks like the highest available skill is %d", nextmap.last_skill);
      self.max_skill = nextmap.last_skill;
    } else if (nextmap.last_skill >= self.filters_by_skill.Size()) {
      // If not, is this a new skill level?
      DEBUG("Inserting spawn filter %d for skill %d", ::Util.GetSpawnFilter(), nextmap.last_skill);
      self.filters_by_skill.Push(::Util.GetSpawnFilter());
      self.all_filters |= ::Util.GetSpawnFilter();
    }

    // If this was the last skill to scan, get all the stuff from LevelLocals,
    // and scan for exits.
    if (MapFullyScanned(nextmap)) {
      nextmap.CopyFromLevelLocals(level);

      if (clusters && nextmap.hub > 0) {
        EnqueueCluster(nextmap.hub, nextmap);
      }

      if (recurse && !nextmap.prune) {
        EnqueueLevelports(nextmap);
        EnqueueNext(level.NextSecretMap, nextmap);
        EnqueueNext(level.NextMap, nextmap);
      }
    }

    // This will either select a new skill level for this map and start an
    // additional scanning pass, or it will flush this map and pick a new one
    // from the queue, depending on if it's fully scanned or not.
    return ScanNext();
  }

  void FinalizeScan() {
    ::IPC.Send("SCAN-DONE", "{}");
    ::Util.printf("$GZAP_SCAN_DONE");
  }

  // Scan a single actor as it spawns in. Returns true if it was recorded in the
  // scan.
  bool ScanActor(Actor thing) {
    let nextmap = queued[0];

    if (thing.pos == (0,0,0) && thing is "Inventory") {
      // Probably starting inventory for the player, but double check just in
      // case the mapper really put something at origin.
      if (Inventory(thing).owner) return false;
    }

    if (thing.bISMONSTER && !thing.bCORPSE) {
      // Not currently implemented
      // nextmap.AddLocation(::ScannedMonster.Create(thing));
      return false;
    } else if (thing is "DehackedPickup") {
      return ScanDehacked(nextmap, DehackedPickup(thing));
    } else if (::ScannedItem.ItemCategory(thing) != "") {
      nextmap.AddLocation(::ScannedItem.Create(thing, nextmap.name));
      return true;
    }
    return false;
  }

  void EnqueueLevelports(::ScannedMap prev) {
    foreach (line : level.lines) {
      if (line.special == 74) {
        // Teleport_NewMap
        let info = LevelInfo.FindLevelByNum(line.args[0]);
        if (!info) continue; // teleport is not hooked up, do not attempt
        console.printf("Teleport_NewMap: %d (%d - %s)", line.args[0], info.LevelNum, info.MapName);
        EnqueueNext(info.MapName, prev);
      } else if (line.special == 244) {
        // Exit_Secret
        console.printf("Exit_Secret: %s", level.NextSecretMap);
        EnqueueNext(level.NextSecretMap, prev);
        // This may already have been enqueued via the MAPINFO, but if so it
        // is common in a lot of WADs to list the secret map for an episode as
        // the NextSecretMap for *every* level, whether or not they have an
        // exit or not, which results in an incorrectly low rank for the map.
        // So, we correct the rank here if that happened.
        ForceMapRank(level.NextSecretMap, prev.rank+1);
      }
    }
  }
}

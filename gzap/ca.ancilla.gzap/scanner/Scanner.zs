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

  static void Output(string type, string map, string payload) {
    ::IPC.Send(type, string.format("{ \"map\": \"%s\", %s }", map, payload));
  }

  int QueueSize() {
    return self.queued.Size();
  }

  void SkipLevel(string mapname) {
    string mapname = mapname.MakeUpper();
    skip.Insert(mapname, true);
  }

  bool EnqueueLevel(string mapname, uint rank) {
    string mapname = mapname.MakeUpper();

    if (!LevelInfo.MapExists(mapname)) {
      return false;
    }

    if (maps_by_name.CheckKey(mapname)) {
      // Already enqueued or scanned, do nothing.
      return false;
    }

    let sm = ::ScannedMap.Create(mapname, rank);
    sm.skip = self.skip.GetIfExists(mapname);

    maps_by_name.Insert(mapname, sm);
    queued.Push(sm);
    ::Util.printf("$GZAP_SCAN_MAP_ENQUEUED", sm.name);
    return true;
  }

  // Like EnqueueLevel, but places it at the head of the queue, immediately behind
  // the current level, rather than at the end.
  void EnqueueNext(string mapname, uint rank) {
    if (!EnqueueLevel(mapname, rank)) return;
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

  // Initiate a scan of the next map in the queue.
  // Returns true if one was initiated (and calls level.ChangeLevel()), false if
  // there are no more maps left to scan.
  bool ScanNext() {
    while (queued.Size() > 0) {
      let nextmap = queued[0];
      if (nextmap.skip) {
        DEBUG("ScanNext: skipping %s", nextmap.name);
        queued.Delete(0);
        continue;
      }
      // If we're done scanning this map, move it to the "finished" list and try again.
      if (nextmap.IsScanned()) {
        DEBUG("Head map is done, moving on");
        ::Util.printf("$GZAP_SCAN_MAP_DONE", level.MapName);
        nextmap.Output();
        queued.Delete(0);
        continue;
      }
      // Otherwise, we need to change to it and let the ScanEventHandler kick off
      // the scan.
      DEBUG("Changing to %s", nextmap.name);
      if (level.ClusterFlags & level.CLUSTER_HUB) {
        level.ChangeLevel("GZAPHUB", 0, CHANGELEVEL_NOINTERMISSION, nextmap.NextSkill());
      }
      level.ChangeLevel(nextmap.name, 0, CHANGELEVEL_NOINTERMISSION, nextmap.NextSkill());
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
  bool FinalizeLevel(bool recurse) {
    DEBUG("FinalizeLevel: %d remaining", queued.Size());
    if (queued.Size() == 0) return false;

    let nextmap = queued[0];
    if (nextmap.IsScanned() || !nextmap.IsCurrentLevel()) {
      DEBUG("ScanNext()");
      return ScanNext();
    }

    ::Util.printf("$GZAP_SCAN_MAP_STARTED", level.MapName, ::Util.GetSkillName());

    nextmap.MarkDone();
    if (nextmap.IsScanned()) nextmap.CopyFromLevelLocals(level);

    if (recurse && !nextmap.skip) {
      EnqueueLevelports(nextmap.rank + 1);
      EnqueueNext(level.NextSecretMap, nextmap.rank + 1);
      EnqueueNext(level.NextMap, nextmap.rank + 1);
    }
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
      nextmap.AddLocation(::ScannedItem.Create(thing));
      return true;
    }
    return false;
  }

  void EnqueueLevelports(uint rank) {
    foreach (line : level.lines) {
      if (line.special != 74) continue; // check for Teleport_NewMap
      let info = LevelInfo.FindLevelByNum(line.args[0]);
      if (!info) continue; // teleport is not hooked up, do not attempt
      console.printf("LEVELPORT: %d (%d - %s)", line.args[0], info.LevelNum, info.MapName);
      EnqueueNext(info.MapName, rank);
    }
  }
}

// The actual scanning machinery.
// The ScanEventHandler just initializes one of these and then drives it based
// on netevents and level entry events.

#namespace GZAP;
#debug off;

#include "../actors/DehackedPickupProber.zsc"
#include "./ScannedMap.zsc"

class ::Scanner play {
  Array<::ScannedMap> scanned;
  Array<::ScannedMap> queued;
  Map<string, ::ScannedMap> maps_by_name;

  static void Output(string type, string map, string payload) {
    ::IPC.Send(type, string.format("{ \"map\": \"%s\", %s }", map, payload));
  }

  int QueueSize() {
    return self.queued.Size();
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
      // If we're done scanning this map, move it to the "finished" list and try again.
      if (nextmap.IsScanned()) {
        scanned.Push(nextmap);
        queued.Delete(0);
        ::Util.printf("$GZAP_SCAN_MAP_DONE", level.MapName);
        nextmap.Output();
        continue;
      }
      // Otherwise, we need to change to it and let the ScanEventHandler kick off
      // the scan.
      level.ChangeLevel(nextmap.name, 0, CHANGELEVEL_NOINTERMISSION, nextmap.NextSkill());
      return true;
    }
    // Queue is empty! We're done scanning for now.
    return false;
  }

  void ScanDehacked(::ScannedMap nextmap, DehackedPickup thing) {
    DEBUG("DEH probe routine: %s [%s]", thing.GetTag(), thing.GetClassName());
    let prober = ::DehackedPickupProber(thing.Spawn("::DehackedPickupProber", thing.pos, NO_REPLACE));
    thing.CallTryPickup(prober);
    if (!prober.real_item) {
      prober.Destroy();
      return;
    }
    nextmap.AddLocation(prober.real_item);
    prober.Destroy();
  }

  // Scan the current level.
  // This is called automatically by ScanEventHandler when we enter a level or
  // initiate a scan. In the former case, it doesn't actually know what's in the
  // queue so it's important we verify that we actually ended up at the level
  // we want to scan.
  bool ScanLevel(bool recurse) {
    if (queued.Size() == 0) return false;

    let nextmap = queued[0];
    if (nextmap.IsScanned() || !nextmap.IsCurrentLevel()) {
      return ScanNext();
    }

    ::Util.printf("$GZAP_SCAN_MAP_STARTED", level.MapName, ::Util.GetSkillName());

    foreach (Actor thing : ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT)) {
      if (thing.bISMONSTER && !thing.bCORPSE) {
        // Not currently implemented
        // nextmap.AddLocation(::ScannedMonster.Create(thing));
      } else if (thing is "DehackedPickup") {
        ScanDehacked(nextmap, DehackedPickup(thing));
      } else if (::ScannedItem.ItemCategory(thing) != "") {
        nextmap.AddLocation(::ScannedItem.Create(thing));
      }
    }

    nextmap.MarkDone();
    if (recurse) {
      EnqueueNext(level.NextSecretMap, nextmap.rank + 1);
      EnqueueNext(level.NextMap, nextmap.rank + 1);
    }
    return ScanNext();
  }
}

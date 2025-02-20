// The actual scanning machinery.
// The ScanEventHandler just initializes one of these and then drives it based
// on netevents and level entry events.

#namespace GZAP;

#include "./ScannedMap.zsc"

class ::Scanner play {
  Array<::ScannedMap> scanned;
  Array<::ScannedMap> queued;
  Map<string, ::ScannedMap> maps_by_name;

  static void Output(string type, string map, string payload) {
    ::IPC.Send(type, string.format("{ \"map\": \"%s\", %s }", map, payload));
  }

  void EnqueueCurrent() {
    EnqueueLevel(level.MapName.MakeUpper());
  }

  void EnqueueLevel(string mapname) {
    string mapname = mapname.MakeUpper();

    if (maps_by_name.CheckKey(mapname)) {
      // Already enqueued or scanned, do nothing.
      return;
    }

    if (!LevelInfo.MapExists(mapname)) {
      return;
    }

    let sm = ::ScannedMap.Create(mapname);

    maps_by_name.Insert(mapname, sm);
    queued.Push(sm);
    ::Util.printf("$GZAP_SCAN_MAP_ENQUEUED", sm.name);
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
        nextmap.Output();
        continue;
      }
      // Otherwise, we need to change to it and let the ScanEventHandler kick off
      // the scan.
      level.ChangeLevel(nextmap.name, 0, CHANGELEVEL_NOINTERMISSION);
      return true;
    }
    // Queue is empty! We're done scanning for now.
    return false;
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
      // EventHandler.SendNetworkEvent("ap-next", 0, 0, 0);
      // TODO: can we get away with this, or do we need to send the netevent?
      return ScanNext();
    }

    ::Util.printf("$GZAP_SCAN_MAP_STARTED", level.MapName);

    // ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
    // Actor thing;

    foreach (Actor thing : ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT)) {
      if (thing.bISMONSTER && !thing.bCORPSE) {
        // nextmap.AddLocation(::ScannedMonster.Create(thing));
        // Not currently implemented
      } else if (::ScannedItem.ItemCategory(thing) != "") {
        nextmap.AddLocation(::ScannedItem.Create(thing));
      }
    }

    nextmap.MarkDone();
    EnqueueLevel(level.NextMap);
    EnqueueLevel(level.NextSecretMap);
    ::Util.printf("$GZAP_SCAN_MAP_DONE", level.MapName);
    return ScanNext();
  }
}

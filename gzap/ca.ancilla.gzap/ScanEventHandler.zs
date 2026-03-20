#namespace GZAP;
#debug off;

#include "./IPC.zsc"
#include "./RC.zsc"
#include "./Util.zsc"
#include "./scanner/Scanner.zsc"

class ::ScanEventHandler : StaticEventHandler {
  bool scan_enabled;
  ::Scanner scanner;
  ::RC rc;
  int timer;
  bool in_sequence;

  override void OnRegister() {
    self.scan_enabled = false;
    self.scanner = ::Scanner(new("::Scanner"));
    self.rc = ::RC.LoadAll("GZAPRC");
    self.rc.ApplyScannerSettings();
  }

  override void WorldLoaded(WorldEvent evt) {
    if (!scan_enabled) return;
    if (self.scanner.queued.Size() == 0) return;
    let name = self.scanner.queued[0].name;
    if (level.MapName == name) {
      // We have arrived at the level we're meant to be scanning.
      // All is well.
      in_sequence = true;
      ::Util.printf("$GZAP_SCAN_MAP_STARTED", name, ::Util.GetSkillName());
    } else {
      // We have arrived somewhere else, probably the GZAPHUB.
      // Warp us back to the target.
      in_sequence = false;
      DEBUG("Scanner is out of sequence, assuming a cluster reset and sending it back to %s", name);
    }
  }

  override void WorldThingSpawned(WorldEvent evt) {
    if (!scan_enabled || !in_sequence) return;
    let thing = evt.thing;
    if (!thing) return;
    // DEBUG("WTS: %s", thing.GetTag());
    if (scanner.ScanActor(thing)) timer = 0;
  }

  override void WorldTick() {
    if (!scan_enabled) return;
    if (!in_sequence) {
      level.ChangeLevel(self.scanner.queued[0].name, 0, CHANGELEVEL_NOINTERMISSION, self.scanner.target_skill);
      return;
    }
    timer++;
    if (timer > 2) {
      DEBUG("Timer expired, finalizing level");
      timer = 0;
      scan_enabled = scanner.FinalizeLevel(ap_scan_recurse, ap_scan_clusters);
      if (!scan_enabled) scanner.FinalizeScan();
    }
  }

  override void NetworkProcess(ConsoleEvent evt) {
    DEBUG("SEH netevent: %s", evt.name);
    if (evt.name == "ap-scan:start") {
      if (!self.scan_enabled) {
        // Do ap_scan_skip first, so that if levels appear in both they are
        // properly flagged as "to skip" and will be used as search roots but
        // not emitted into the logic file.
        Array<string> levels;
        ap_scan_skip.Split(levels, " ", TOK_SKIPEMPTY);
        foreach (levelname : levels) {
          scanner.SkipLevel(levelname);
        }

        levels.Clear();
        ap_scan_prune.Split(levels, " ", TOK_SKIPEMPTY);
        foreach (levelname : levels) {
          scanner.PruneLevel(levelname);
        }

        levels.Clear();
        ap_scan_levels.Split(levels, " ", TOK_SKIPEMPTY);
        foreach (levelname : levels) {
          scanner.EnqueueLevel(levelname, null);
        }

        if (scanner.QueueSize() < 1) {
          ::Util.printf("$GZAP_SCAN_EMPTY");
          return;
        }
        scanner.Init();
        scan_enabled = scanner.ScanNext();
        // EventHandler.SendNetworkEvent("ap-scan:continue", 0, 0, 0);
      }
    // } else if (evt.name == "ap-scan:continue") {
    //   self.scan_enabled = scanner.ScanLevel(ap_scan_recurse);
    //   if (!self.scan_enabled) {
    //     ::IPC.Send("SCAN-DONE", "{}");
    //     ::Util.printf("$GZAP_SCAN_DONE");
    //   }
    }
    // TODO: add a way to re-dump the scan results e.g. if someone forgot to turn
    // on logging. ap-scan:write perhaps.
  }
}

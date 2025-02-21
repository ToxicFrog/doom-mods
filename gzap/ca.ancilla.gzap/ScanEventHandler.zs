#namespace GZAP;
#debug on;

#include "./IPC.zsc"
#include "./Util.zsc"
#include "./scanner/Scanner.zsc"

class ::ScanEventHandler : StaticEventHandler {
  Array<string> queue;
  Array<string> done;
  bool scan_enabled;
  ::Scanner scanner;

  override void OnRegister() {
    self.scan_enabled = false;
    self.scanner = ::Scanner(new("::Scanner"));
  }

  override void WorldLoaded(WorldEvent evt) {
    if (!scan_enabled) return;
    // As soon as we load into a new map, queue up a scan.
    // We can't do it immediately by calling ScanLevel() or things break?
    EventHandler.SendNetworkEvent("ap-scan", 0, 0, 0);
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.name == "ap-scan") {
      if (!self.scan_enabled) {
        ::Util.printf("$GZAP_SCAN_STARTING");
        scanner.EnqueueCurrent();
      }
      self.scan_enabled = scanner.ScanLevel(true);
      if (!self.scan_enabled) {
        ::IPC.Send("SCAN-DONE", "{}"); // TODO: include information about WAD name etc
        ::Util.printf("$GZAP_SCAN_DONE");
      }
    } else if (evt.name == "ap-next") {
      // not currently used
      self.scan_enabled = scanner.ScanNext();
      if (!self.scan_enabled) {
        ::IPC.Send("SCAN-DONE", "{}"); // TODO: include information about WAD name etc
        ::Util.printf("$GZAP_SCAN_DONE");
      }
    }
  }
}

// TODO: multi-difficulty scanning
// We can do this in one pass by repeatedly entering the level at difficulty 1, 2, and 3
// First pass, we record some basic map info + a list of all actors we care about,
// storing only the data we need to send out to the rando
// Second and third pass, foreach actor, we try to match it up with an existing actor
// in the list and update its difficulty bits; we record a new actor iff we can't match
// it to an existing one.
// Then we dump all actors; ones that only occur on some difficulties will have a
// "difficulty": [1,2,3] field. We omit the field entirely on actors that occur on
// all difficulty levels.
// Then, rather than having a separate wad definition per difficulty, we just tell
// the wad what difficulty we want items/locations for it and it returns only the ones
// with the appropriate tags.


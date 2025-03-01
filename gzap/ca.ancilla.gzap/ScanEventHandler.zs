#namespace GZAP;
#debug off;

#include "./IPC.zsc"
#include "./Util.zsc"
#include "./scanner/Scanner.zsc"

class ::ScanEventHandler : StaticEventHandler {
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
    EventHandler.SendNetworkEvent("ap-scan:continue", 0, 0, 0);
  }

  override void NetworkProcess(ConsoleEvent evt) {
    DEBUG("SEH netevent: %s", evt.name);
    if (evt.name == "ap-scan:start") {
      if (!self.scan_enabled) {
        Array<string> levels;
        ap_scan_levels.Split(levels, " ", TOK_SKIPEMPTY);
        foreach (levelname : levels) {
          scanner.EnqueueLevel(levelname, 0);
        }
        if (scanner.QueueSize() < 1) {
          ::Util.printf("$GZAP_SCAN_EMPTY");
          return;
        }
        ::Util.printf("$GZAP_SCAN_STARTING");
        EventHandler.SendNetworkEvent("ap-scan:continue", 0, 0, 0);
      }
    } else if (evt.name == "ap-scan:continue") {
      self.scan_enabled = scanner.ScanLevel(ap_scan_recurse);
      if (!self.scan_enabled) {
        ::IPC.Send("SCAN-DONE", "{}");
        ::Util.printf("$GZAP_SCAN_DONE");
      }
    }
    // TODO: add a way to re-dump the scan results e.g. if someone forgot to turn
    // on logging. ap-scan:write perhaps.
  }
}

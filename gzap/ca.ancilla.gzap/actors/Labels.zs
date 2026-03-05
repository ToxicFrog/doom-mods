#namespace GZAP;

// This is a special actor used to force all the AP icons to load.
// It is never instantiated in-game.
class ::IconLoader : Actor {
  States {
    Spawn:
      AP01 ABCDEFGHIJKLMNOPQRSTUVWXYZ -1;
      STOP;
  }
}

// A very simple alarm clock that waits 10 tics and then calls back into the
// PlayEventHandler that created it.

#namespace GZAP;

class ::AlarmClock : Actor {
  States {
    Spawn:
      TNT1 A 10 NODELAY;
      TNT1 A 0 Ring();
      STOP;
  }

  void Ring() {
    ::PlayEventHandler.Get().Alarm();
    Destroy();
  }
}

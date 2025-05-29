#namespace GZAP;

// These are special actors used to provide "what does this check contain" icons
// for items that exist only in Archipelago.
// They are never to be instantiated in-game; they exist solely so that the
// corresponding sprites get loaded into memory and so that looking up the sprite
// ID by actor name works.

class ::LevelAccess : Actor {
  States {
    Spawn:
      AP00 A -1;
      STOP;
  }
}

class ::Automap : Actor {
  States {
    Spawn:
      AP00 M -1;
      STOP;
  }
}

class ::IconLoader : Actor {
  States {
    Spawn:
      AP01 ABCDEFGHIJKLMNOPQRSTUVWXYZ -1;
      STOP;
  }
}

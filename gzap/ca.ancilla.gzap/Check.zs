// Classes representing an Archipelago check placeholder.
//
// These are all basically the same thing: a floating Archipelago logo that
// knows what location ID it corresponds to and emits an AP-CHECK event when
// touched. They differ only in what icon they display; progress icons are
// visually different from filler.

#namespace GZAP;

class ::CheckGeneric : ScoreItem {
  int apid;
  string name;

  Default {
    +NOGRAVITY;
    +COUNTITEM;
    +BRIGHT;
    Radius 32;
  }

  States {
    Spawn:
      APIT A -1 BRIGHT;
      STOP;
  }

  override bool TryPickup (in out Actor toucher) {
    console.printf("AP-CHECK { \"id\": %d, \"name\": \"%s\" }",
      self.apid, self.name);
    return super.TryPickup(toucher);
  }
}

class ::CheckProgression : ::CheckGeneric {
  States {
    Spawn:
      APIT B -1 BRIGHT;
      STOP;
  }
}

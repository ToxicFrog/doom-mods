// Classes representing an Archipelago check placeholder.
//
// These are all basically the same thing: a floating Archipelago logo that
// knows what location ID it corresponds to and emits an AP-CHECK event when
// touched. They differ only in what icon they display; progress icons are
// visually different from filler.

#namespace GZAP;

mixin class ::ArchipelagoIcon {
  bool progression;

  States {
    NotProgression:
      APIT A -1 BRIGHT;
      STOP;
    Progression:
      APIT B -1 BRIGHT;
      STOP;
  }

  void SetProgressionState() {
    if (self.progression) {
      SetStateLabel("Progression");
    } else {
      SetStateLabel("NotProgression");
    }
  }
}

class ::CheckMapMarker : MapMarker {
  mixin ::ArchipelagoIcon;

  Default {
    Scale 0.25;
  }

  override void PostBeginPlay() {
    SetProgressionState();
  }
}

class ::CheckPickup : ScoreItem {
  mixin ::ArchipelagoIcon;

  ::CheckInfo info;
  ::CheckMapMarker marker;

  Default {
    Inventory.PickupMessage "";
    +COUNTITEM;
    +BRIGHT;
    +MOVEWITHSECTOR;
    Height 10;
  }

  static ::CheckPickup Create(::CheckInfo info, Vector3 pos) {
    let thing = ::CheckPickup(Actor.Spawn("::CheckPickup", pos));
    thing.info = info;
    thing.progression = info.progression;
    return thing;
  }

  override void PostBeginPlay() {
    SetProgressionState();
    ChangeTID(level.FindUniqueTID());
    marker = ::CheckMapMarker(Spawn("::CheckMapMarker", self.pos));
    marker.progression = self.progression;
    marker.A_SetSpecial(0, self.tid);
  }

  override bool TryPickup (in out Actor toucher) {
    ::PlayEventHandler.Get().CheckLocation(self.info.apid, self.info.name);
    return super.TryPickup(toucher);
  }

  override void OnDestroy() {
    if (self.marker) self.marker.Destroy();
  }
}

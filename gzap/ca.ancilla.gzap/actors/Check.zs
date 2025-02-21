// Classes representing an Archipelago check placeholder.

#namespace GZAP;

#include "../archipelago/Location.zsc"

// Mixin for the icon itself which is displayed by both the in-world actor and
// the map icon. The progression bit determines which version of the icon is
// displayed.
mixin class ::ArchipelagoIcon {
  bool progression;

  States {
    Spawn:
      // We need one dead frame so that it doesn't SetProgressionState() before
      // the creator can set the progression bit.
      TNT1 A 1 NODELAY;
      TNT1 A 0 SetProgressionState();
    NotProgression:
      APIT A -1 BRIGHT;
      STOP;
    Progression:
      APIT B -1 BRIGHT;
      STOP;
    Hidden:
      TNT1 A -1;
      STOP;
  }

  void SetProgressionState() {
    if (!ShouldDisplay()) {
      SetStateLabel("Hidden");
    } else if (self.progression && ShouldHilight()) {
      SetStateLabel("Progression");
    } else {
      SetStateLabel("NotProgression");
    }
  }

  // Implementing classes should define this to control whether the icon is
  // displayed at all.
  // abstract bool ShouldDisplay();
  // Implementing classes should define this to control whether progression
  // items are displayed differently or not.
  // abstract bool ShouldHilight() { return true; }
}

// An automap marker that follows the corresponding CheckPickup around.
class ::CheckMapMarker : MapMarker {
  mixin ::ArchipelagoIcon;

  Default {
    Scale 0.25;
  }

  bool ShouldDisplay() {
    if (ap_show_checks_on_map <= 0) return false;
    if (ap_show_checks_on_map >= 2) return true;
    return ::PlayEventHandler.GetState().GetCurrentRegion().automap;
  }

  bool ShouldHilight() {
    if (ap_show_progression <= 1) return false; // "never" or "only in person"
    if (ap_show_progression == 2) {
      return ::PlayEventHandler.GetState().GetCurrentRegion().automap;
    }
    return true;
  }
}

// The actual in-world item the player can pick up.
// Knows about its backing Location, and thus its name, ID, etc.
// Automatically creates a map marker on spawn, and deletes it on despawn.
// When picked up, emits an AP-CHECK event.
class ::CheckPickup : ScoreItem {
  mixin ::ArchipelagoIcon;

  ::Location location;
  ::CheckMapMarker marker;

  Default {
    Inventory.PickupMessage "";
    +COUNTITEM;
    +BRIGHT;
    +MOVEWITHSECTOR;
    Height 10;
  }

  static ::CheckPickup Create(::Location location, Actor original) {
    let thing = ::CheckPickup(Actor.Spawn("::CheckPickup", original.pos));
    thing.location = location;
    thing.progression = location.progression;
    thing.A_SetSize(original.radius, original.height);
    // TODO: copy flags like gravity from the original?
    return thing;
  }

  bool ShouldDisplay() { return true; }
  bool ShouldHilight() {
    return ap_show_progression > 0;
  }

  override void PostBeginPlay() {
    SetTag(self.location.name);
    ChangeTID(level.FindUniqueTID());
    marker = ::CheckMapMarker(Spawn("::CheckMapMarker", self.pos));
    marker.progression = self.progression;
    marker.A_SetSpecial(0, self.tid);
  }

  override bool TryPickup (in out Actor toucher) {
    ::PlayEventHandler.Get().CheckLocation(self.location.apid, self.location.name);
    return super.TryPickup(toucher);
  }

  override void OnDestroy() {
    if (self.marker) self.marker.Destroy();
  }
}

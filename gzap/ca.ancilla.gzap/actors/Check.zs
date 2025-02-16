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
  }

  void SetProgressionState() {
    if (self.progression) {
      SetStateLabel("Progression");
    } else {
      SetStateLabel("NotProgression");
    }
  }
}

// An automap marker that follows the corresponding CheckPickup around.
class ::CheckMapMarker : MapMarker {
  mixin ::ArchipelagoIcon;

  Default {
    Scale 0.25;
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
    return thing;
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

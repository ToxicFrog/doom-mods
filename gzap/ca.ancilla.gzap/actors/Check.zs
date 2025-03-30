// Classes representing an Archipelago check placeholder.

#namespace GZAP;
#debug off;

#include "../archipelago/Location.zsc"

// Mixin for the icon itself which is displayed by both the in-world actor and
// the map icon. The progression bit determines which version of the icon is
// displayed.
mixin class ::ArchipelagoIcon {
  bool progression;
  bool unreachable;
  bool checked;

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
      APIT ABCDEFGHIJIHGFEDCB 2 BRIGHT;
      LOOP;
    Unreachable:
      APUR ABCDEFGHIJIHGFEDCB 2 BRIGHT;
      LOOP;
    Hidden:
      TNT1 A -1;
      STOP;
  }

  void SetProgressionState() {
    if (self.checked) {
      A_SetRenderStyle(CVar.FindCVar("ap_collected_alpha").GetFloat(), STYLE_Translucent);
    }

    if (!ShouldDisplay()) {
      SetStateLabel("Hidden");
    } else if (self.unreachable) {
      SetStateLabel("Unreachable");
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
    +DONTGIB;
    Height 10;
  }

  static ::CheckPickup Create(::Location location, Actor original) {
    let thing = ::CheckPickup(Actor.Spawn("::CheckPickup", original.pos));
    thing.location = location;
    thing.progression = location.progression;
    thing.unreachable = location.unreachable;
    thing.checked = location.checked;
    thing.A_SetSize(original.radius, original.height);
    DEBUG("Check initialize: name=%s, pr=%d, ur=%d, ck=%d", location.name, thing.progression, thing.unreachable, thing.checked);
    if (thing.checked) level.found_items++;
    // TODO: copy flags like gravity from the original?
    return thing;
  }

  bool ShouldDisplay() { return true; }
  bool ShouldHilight() {
    return ap_show_progression > 0;
  }

  override void PostBeginPlay() {
    if (self.unreachable) self.ClearCounters();
    if (self.checked) return;
    DEBUG("Creating map marker for check %s", self.location.name);
    SetTag(self.location.name);
    ChangeTID(level.FindUniqueTID());
    marker = ::CheckMapMarker(Spawn("::CheckMapMarker", self.pos));
    marker.progression = self.progression;
    marker.unreachable = self.unreachable;
    marker.checked = self.checked;
    marker.A_SetSpecial(0, self.tid);
  }

  override bool CanPickup(Actor toucher) {
    DEBUG("CanPickup? %s %s %d", self.location.name, toucher.GetTag(), !self.checked);
    return !self.checked;
  }

  void UpdateStatus() {
    self.checked = self.location.checked;
    SetProgressionState();
  }

  override bool TryPickup (in out Actor toucher) {
    // I should probably check checked here, destroy the marker, flag this checked,
    // etc rather than spreading it across OnDestroy etc
    DEBUG("TryPickup: %s", self.location.name);
    ::PlayEventHandler.Get().CheckLocation(self.location.apid, self.location.name);
    // It might take the server a moment to respond and set location.checked, so
    // instead of calling UpdateStatus() here, we just force checked locally.
    // It'll get re-checked next time the level loads, so the player will have
    // a chance to re-collect it if the server didn't register it.
    self.checked = true;
    self.SetProgressionState();
    if (CVar.FindCVar("ap_show_check_names").GetBool()) {
      toucher.A_Print(string.format("Checked %s", self.location.name));
    }
    if (self.marker) self.marker.Destroy();
    return true;
  }

  override bool ShouldStay() { return true; }

  override void OnDestroy() {
    DEBUG("Destroying marker %s", self.location.name);
    if (self.marker) self.marker.Destroy();
  }
}

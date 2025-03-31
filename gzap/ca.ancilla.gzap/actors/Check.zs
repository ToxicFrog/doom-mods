// Classes representing an Archipelago check placeholder.

#namespace GZAP;
#debug off;

#include "../archipelago/Location.zsc"

// Mixin for the icon itself which is displayed by both the in-world actor and
// the map icon. The progression bit determines which version of the icon is
// displayed.
mixin class ::ArchipelagoIcon {
  States {
    Spawn:
      TNT1 A 0;
      TNT1 A 0 SetProgressionState();
      STOP;
    NotProgression:
      APIT A 35 BRIGHT;
      TNT1 A 0 SetProgressionState();
      LOOP;
    Progression:
      APIT ABCDEFGHIJIHGFEDCB 2 BRIGHT;
      TNT1 A 0 SetProgressionState();
      LOOP;
    Unreachable:
      APUR A 35 BRIGHT;
      TNT1 A 0 SetProgressionState();
      LOOP;
    Hidden:
      TNT1 A 35;
      TNT1 A 0 SetProgressionState();
      LOOP;
  }

  void SetProgressionState() {
    DEBUG("SetProgressionState(%s) checked=%d display=%d unreachable=%d progression=%d hilight=%d",
      GetLocation().name,
      GetLocation().checked, ShouldDisplay(), GetLocation().unreachable, GetLocation().progression, ShouldHilight());
    if (GetLocation().checked) {
      A_SetRenderStyle(CVar.FindCVar("ap_collected_alpha").GetFloat(), STYLE_Translucent);
    }

    if (!ShouldDisplay()) {
      SetStateLabel("Hidden");
    } else if (GetLocation().unreachable) {
      SetStateLabel("Unreachable");
    } else if (GetLocation().progression && ShouldHilight()) {
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
  ::CheckPickup parent;

  Default {
    Scale 0.25;
  }

  ::Location GetLocation() { return parent.GetLocation(); }

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

  // We keep a local "checked" bit so we can set it immediately when the player
  // picks it up, and not fire a huge number of pickup events.
  // This is updated from the location every time the level is entered (including
  // in persistent mode), so if a message gets lost, re-entering the level will
  // respawn the check.
  bool checked;

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
    thing.UpdateFromLocation();
    thing.A_SetSize(original.radius, original.height);
    DEBUG("Check initialize: name=%s, pr=%d, ur=%d, ck=%d",
      location.name, location.progression, location.unreachable, location.checked);
    if (location.checked) level.found_items++;
    // TODO: copy flags like gravity from the original?
    return thing;
  }

  ::Location GetLocation() { return self.location; }
  bool ShouldDisplay() { return true; }
  bool ShouldHilight() {
    return ap_show_progression > 0;
  }

  void UpdateFromLocation() {
    self.checked = self.location.checked;
  }

  override void PostBeginPlay() {
    if (self.location.unreachable) self.ClearCounters();
    if (self.location.checked) return;
    DEBUG("Creating map marker for check %s", self.location.name);
    SetTag(self.location.name);
    ChangeTID(level.FindUniqueTID());
    marker = ::CheckMapMarker(Spawn("::CheckMapMarker", self.pos));
    marker.parent = self;
    marker.A_SetSpecial(0, self.tid);
  }

  override bool CanPickup(Actor toucher) {
    DEBUG("CanPickup? %s %s %d", self.location.name, toucher.GetTag(), !self.checked);
    return !self.checked;
  }

  override bool TryPickup (in out Actor toucher) {
    DEBUG("TryPickup: %s", self.location.name);
    ::PlayEventHandler.Get().CheckLocation(self.location.apid, self.location.name);
    // It might take the server a moment to respond and set location.checked, so
    // we force the checked flag locally.
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

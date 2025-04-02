// Classes representing an Archipelago check placeholder.

#namespace GZAP;
#debug off;

#include "../archipelago/Location.zsc"
#include "./Labels.zsc"

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
      GetLocation().name, IsChecked(),
      ShouldDisplay(), GetLocation().unreachable, GetLocation().progression, ShouldHilight());
    if (IsChecked()) {
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

  // Implementing classes should define the following methods:
  //    abstract bool ShouldDisplay();
  // To determine whether to render at all;
  //    abstract bool ShouldHilight() { return true; }
  // To determine whether progression items should glow;
  //    abstract ::Location GetLocation()
  // To return the backing ::Location object;
  //    abstract bool IsChecked()
  // To return if the location is checked or not.
}

// An automap marker that follows the corresponding CheckPickup around.
class ::CheckMapMarker : MapMarker {
  mixin ::ArchipelagoIcon;
  ::CheckPickup parent;

  Default {
    Scale 0.25;
  }

  ::Location GetLocation() { return parent.GetLocation(); }
  bool IsChecked() { return GetLocation().checked; }

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

// Used to display the floating item label above the check, if the player has
// turned those on.
class ::CheckLabel : Actor {
  ::CheckPickup parent;
  int zoffs;

  Default {
    +BRIGHT;
    +NOGRAVITY;
    +DONTGIB;
    +NOBLOCKMAP;
    +NOINTERACTION;
    Scale 0.5;
  }

  override void Tick() {
    self.SetOrigin(parent.pos + (0, 0, zoffs), false);
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
  ::CheckLabel label;
  ::CheckLabel orig_label;

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
  bool IsChecked() { return self.checked; }
  bool ShouldDisplay() { return true; }
  bool ShouldHilight() {
    return ap_show_progression > 0;
  }

  void UpdateFromLocation() {
    self.checked = self.location.checked;
    if (self.checked) {
      if (self.label) self.label.Destroy();
      if (self.orig_label) self.orig_label.Destroy();
    }
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

    // Spawn the labels for the original + actual item.
    DEBUG("Spawn label: %s -> %s [%s]", self.location.orig_typename, self.location.ap_typename, self.location.ap_name);
    if (ap_show_check_contents) self.label = CreateLabel(self.location.ap_typename);
    if (ap_show_check_original) self.orig_label = CreateLabel(self.location.orig_typename, 32);
  }

  // Create a sprite label attached to this CheckPickup for the given type.
  // If zoffs is unspecified, it will try to center it in the Check sprite.
  // The label will be half the height of the original or 12px high, whichever
  // is smaller. (For reference, the Check sprite is 32x32).
  ::CheckLabel CreateLabel(string typename, int zoffs = -1) {
    // Start with some basic checks. We can't create a label if we don't know
    // the corresponding class, if it has no SpawnState sprite, or if the
    // sprite is 0-height.
    Class<Actor> cls = typename;
    if (!cls) return null;

    let prototype = GetDefaultByType(cls);
    let sprid = prototype.SpawnState.sprite;
    if (!sprid) return null;

    let texid = prototype.SpawnState.GetSpriteTexture(0);
    let [w,h] = TexMan.GetSize(texid);
    let rh = TexMan.CheckRealHeight(texid);
    if (!rh) return null;

    // Scale is computed to make the sprite at most 12px high and will not
    // exceed 0.5 under any circumstances.
    float scale = min(0.5, 12.0/rh);
    // Center it in the AP sprite.
    if (zoffs < 0) zoffs = floor(16 - (rh*scale)/2.0 - scale*max(0, h - rh));

    DEBUG("Sprite: %d [tx %d, %dx%d (x%d)], scale=%f, z=%d", sprid, texid, w, h, rh, scale, zoffs);
    let label = ::CheckLabel(Spawn("::CheckLabel", (pos.x, pos.y, pos.z+zoffs)));
    label.sprite = sprid;
    label.parent = self;
    label.zoffs = zoffs;
    label.A_SetScale(scale);
    return label;
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
    if (self.marker) self.marker.Destroy();
    if (self.label) self.label.Destroy();
    if (self.orig_label) self.orig_label.Destroy();
    return true;
  }

  override bool ShouldStay() { return true; }

  override void OnDestroy() {
    DEBUG("Destroying marker %s", self.location.name);
    if (self.marker) self.marker.Destroy();
    if (self.label) self.label.Destroy();
    if (self.orig_label) self.orig_label.Destroy();
  }
}

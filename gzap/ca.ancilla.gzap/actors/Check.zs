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
    SetProgression:
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
    // DEBUG("SetProgressionState(%s) checked=%d display=%d unreachable=%d progression=%d hilight=%d",
    //   GetLocation().name, IsChecked(),
    //   ShouldDisplay(), GetLocation().unreachable, GetLocation().progression, ShouldHilight());
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
  ::Location location;

  Default {
    Scale 0.25;
    // TODO: MapMarkers don't respect AutomapOffsets or A_SpriteOffset. If we
    // want them to display centered on the map, we need to give the sprite
    // itself centered offsets, and then A_SpriteOffset() on the in-world object
    // to keep it from clipping into the floor.
  }

  ::Location GetLocation() { return self.location; }
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

class ::ItemMapMarker : ::CheckMapMarker {
  ::CheckPickup parent;

  override void Tick() {
    self.SetOrigin(self.parent.pos, false);
    super.Tick();
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
  ::ItemMapMarker marker;
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

  States {
    Spawn:
      // Try for the first several tics to find a matching item to absorb.
      // If we can, Subsume() will jump us straight to SetProgression.
      // Otherwise, NoOriginal will do some setup based on the defaults of the
      // type, if possible.
      APIT AAAAAAA 1 Subsume();
      APIT A 1 NoOriginal();
      GOTO SetProgression;
  }

  static ::CheckPickup Create(::Location location) {
    let thing = ::CheckPickup(Actor.Spawn("::CheckPickup", location.pos));
    thing.location = location;
    DEBUG("Check initialize: name=%s, pr=%d, ur=%d, ck=%d",
      location.name, location.progression, location.unreachable, location.checked);
    if (location.checked) level.found_items++;
    return thing;
  }

  ::Location GetLocation() { return self.location; }
  bool IsChecked() { return self.checked; }
  bool ShouldDisplay() { return true; }
  bool ShouldHilight() {
    return ap_show_progression > 0;
  }

  //// Initialization ////

  override void PostBeginPlay() {
    if (self.location.unreachable) self.ClearCounters();
    UpdateFromLocation();
  }

  void Subsume() {
    // Don't subsume if this is an unreachable check -- leave the original item
    // in place just in case.
    if (GetLocation().unreachable) return;
    DEBUG("Check[%s] Subsume", self.location.name);
    Actor closest;
    let it = BlockThingsIterator.Create(self, 32);
    while (it.Next()) {
      Actor thing = it.thing;
      if (thing is "::CheckPickup") continue;

      // TODO -- prefer things that match the recorded check category, if possible.
      // TODO -- don't absorb things like AAS tokens that have no graphics.
      if (::ScannedItem.ItemCategory(thing) == "") {
        // If it's categorized, we skip these checks entirely -- a categorized
        // object is always replaceable.
        if (thing.bNOSECTOR || thing.bNOINTERACTION || thing.bISMONSTER) continue;
        if (!(thing is "Inventory")) continue;
      }

      // Don't eat invisible things. They're probably tokens created by something
      // like Intelligent Supplies or AutoAutoSave.
      if (thing.CurState.Sprite == 0) continue;

      if (!closest || Distance3D(thing) < Distance3D(closest)) {
        closest = thing;
        DEBUG("Check[%s]: closest is %s (d=%f)", self.location.name, closest.GetClassName(), Distance3D(closest));
      }
    }

    if (!closest) return;
    if (Distance3D(closest) < 2.0) {
      UpdateFromOriginal(closest);
      closest.Destroy();
      SetStateLabel("SetProgression");
    }
  }

  void NoOriginal() {
    DEBUG("Check[%s] couldn't find its original, imagining one instead", self.location.name);
    Class<Actor> cls = self.location.orig_typename;
    let orig = GetDefaultByType(cls);
    if (!orig) return;
    UpdateFromOriginal(orig);
  }

  void UpdateFromLocation() {
    self.checked = self.location.checked;
    SetTag(self.location.name);
    if (self.checked) {
      DEBUG("Check[%s] clearing markers", self.location.name);
      ClearMarkers();
    } else {
      DEBUG("Check[%s] creating markers", self.location.name);
      CreateMarkers();
    }
  }

  void UpdateFromOriginal(readonly<Actor> original) {
    if (!original) return;
    A_SetSize(original.radius, original.height);
    ChangeTID(original.TID);
    A_SetSpecial(original.special, original.args[0], original.args[1], original.args[2], original.args[3], original.args[4]);
    self.bNOGRAVITY = original.bNOGRAVITY;
  }

  //// Label/Marker handling ////

  // Create a sprite label attached to this CheckPickup for the given type.
  // If zoffs is unspecified, it will try to center it in the Check sprite.
  // The label will be half the height of the original or 12px high, whichever
  // is smaller. (For reference, the Check sprite is 32x32).
  ::CheckLabel CreateLabel(string typename, int zoffs = -1) {
    // If the typename starts with ICON:, AP has already selected an icon for
    // us to use.
    if (typename.Left(5) == "ICON:") {
      return CreateIconLabel(typename);
    }

    // If AP couldn't select an icon and it's not a Doom item, it's just recorded
    // as "NONE:game name:item name" for later mapping.
    if (typename.Left(5) == "NONE:") {
      return null;
    }

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
    let soffs = TexMan.GetScaledOffset(texid);
    if (!rh) return null;

    // Scale is computed to make the sprite at most 12px high and will not
    // exceed 0.5 under any circumstances, except when pretuning.
    float scale = min(0.5, 12.0/rh);
    if (::PlayEventHandler.Get().IsPretuning()) {
      scale = min(prototype.scale.x, prototype.scale.y);
    }

    // Center it in the AP sprite.
    if (zoffs < 0) {
      zoffs = ceil(16 // Half the height of the AP logo
        - (rh*scale)/2.0 // Center vertically based on real height
        - scale*max(0, h - rh) // adjust based on difference between real and nominal height
        - scale*(soffs.y - h) // adjust based on sprite y-offset
      );
    } else {
      // Just adjust based on y-offset
      zoffs = ceil(zoffs - scale*(soffs.y - h));
    }

    DEBUG("Sprite: %d [tx %d, %dx%d (x%d)], scale=%f, z=%d", sprid, texid, w, h, rh, scale, zoffs);

    let label = ::CheckLabel(Spawn("::CheckLabel", (pos.x, pos.y, pos.z+zoffs)));
    label.sprite = sprid;
    label.parent = self;
    label.zoffs = zoffs;
    label.A_SetScale(scale);
    return label;
  }

  ::CheckLabel CreateIconLabel(string icon) {
    // we encode both the sprite name and the frame index into the icon
    // then we get the sprid with GetSpriteIndex()
    // set label.sprite to the sprid
    // set label.frame to the frame index
    // and away we go
    Array<string> fields;
    icon.Split(Fields, ":");
    let sprid = GetSpriteIndex(fields[1]);
    let frame = fields[2].ToInt(10);
    let zoffs = 16; // Centered in the check icon

    let label = ::CheckLabel(Spawn("::CheckLabel", (pos.x, pos.y, pos.z+zoffs)));
    label.sprite = sprid;
    label.frame = frame;
    label.parent = self;
    label.zoffs = zoffs;
    label.A_SetScale(1.0); // Icons are prescaled
    label.A_SpriteOffset(-8, -8); // 16x16, so this puts the center of the sprite over the center of the actor
    return label;
  }

  void CreateMarkers() {
    if (!self.marker) {
      DEBUG("Check[%s] spawning map marker", self.location.name);
      self.marker = ::ItemMapMarker(Spawn("::ItemMapMarker", self.pos));
      self.marker.parent = self;
      self.marker.location = self.location;
    }
    if (ap_show_check_contents && !self.label) {
      self.label = CreateLabel(self.location.ap_typename);
    }
    if (ap_show_check_original && !self.orig_label && !::PlayEventHandler.Get().IsPretuning()) {
      self.orig_label = CreateLabel(self.location.orig_typename, 34);
    }
  }

  void ClearMarkers() {
    if (self.marker) self.marker.Destroy();
    if (self.label) self.label.Destroy();
    if (self.orig_label) self.orig_label.Destroy();
  }

  //// Pickup event handling ////

  override bool CanPickup(Actor toucher) {
    // DEBUG("CanPickup? %s %s %d", self.location.name, toucher.GetTag(), !self.checked);
    return !self.checked;
  }

  override bool TryPickup (in out Actor toucher) {
    DEBUG("TryPickup: %s", self.location.name);
    ::PlayEventHandler.Get().CheckLocation(self.location);
    // It might take the server a moment to respond and set location.checked, so
    // we force the checked flag locally.
    self.checked = true;
    self.SetProgressionState();
    ClearMarkers();
    return true;
  }

  override bool ShouldStay() { return true; }

  override void OnDestroy() {
    ClearMarkers();
  }
}

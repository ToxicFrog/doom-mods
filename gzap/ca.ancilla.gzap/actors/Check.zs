// Classes representing an Archipelago check placeholder.
//
// A given check has (up to) four parts:
// - the CheckMapMarker, which displays the check on the map (if configured)
// - the CheckLabels, which displays the item in the check and the item the
//   the location had before randomization (if configured)
// - and the CheckPickup, which is the thing the player can actually interact
//   with.
// Note that not all locations have these; in particular, secrets may have a
// CheckMapMarker but not any of the others, and aren't guaranteed to even have
// the map marker.
//
// When we first enter a level, the PerLevelHandler starts the Check lifecycle:
// - a map marker is spawned for every secret sector check
// - a CheckPickup is spawned for every check that exists in the world;
//   these CheckPickups are responsible for spawning their own map markers and
//   item icons
// - all CheckPickups are told to update themselves based on their backing
//   location, and the total item count for the level is recomputed.
//
// On re-entering a level, due to `load or a levelport with persistence on, we
// re-do that last step; this has the effect of making sure that the checks are
// consistent with (our understanding of) the host's view of the game, removing
// checks that were !collected and respawning checks that we touched but that
// the server never acked.

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
    Filler:
      AP00 C 35 BRIGHT;
      GOTO SetProgression;
    Progression:
      AP00 P 35 BRIGHT;
      GOTO SetProgression;
    UsefulProgression:
      AP00 Q 35 BRIGHT;
      GOTO SetProgression;
    Useful:
      AP00 U 35 BRIGHT;
      GOTO SetProgression;
    Trap:
      AP00 T 35 BRIGHT;
      GOTO SetProgression;
    Empty:
      AP00 E 35 BRIGHT;
      GOTO SetProgression;
    Unreachable:
      AP00 Z 35 BRIGHT;
      GOTO SetProgression;
    Hidden:
      TNT1 A 35;
      GOTO SetProgression;
  }

  // ID of the backing Location.
  // We only store the ID, not the actual Location object, so that if the player
  // leaves the level and returns to it, the location doesn't get duplicated
  // (one in the apstate, one in the Check).
  uint location_id;
  ::Location GetLocation() {
    return ::PlayEventHandler.GetState().GetCurrentRegion().GetLocation(self.location_id);
  }
  bool IsChecked() { return GetLocation().IsChecked(); }

  // TODO: we should move this into the CheckPickup, and just have it call
  // SetStateLabel on its map marker if any.
  void SetProgressionState() {
    DEBUG("SetProgressionState(%d)", self.location_id);

    let loc = GetLocation();
    DEBUG("  name=%s checked=%d (ck=%d cl=%d) display=%d unreachable=%d progression=%d hilight=%d trigger=%d",
      loc.name, IsChecked(), loc.checked, loc.collected,
      ShouldDisplay(), loc.IsUnreachable(), loc.IsProgression(), ShouldHilight(), IsTrigger());

    if (self.IsTrigger() && !loc.checked || !loc.IsChecked()) {
      A_SetRenderStyle(CVar.FindCVar("ap_uncollected_alpha").GetFloat(), STYLE_Translucent);
    } else {
      A_SetRenderStyle(CVar.FindCVar("ap_collected_alpha").GetFloat(), STYLE_Translucent);
    }

    if (!ShouldDisplay()) {
      SetStateLabel("Hidden");
    } else if (loc.IsEmpty()) {
      SetStateLabel("Empty");
    } else if (loc.IsUnreachable()) {
      SetStateLabel("Unreachable");
    } else if (loc.IsProgression() && ShouldHilight()) {
      if (loc.IsUseful()) {
        SetStateLabel("UsefulProgression");
      } else {
        SetStateLabel("Progression");
      }
    } else if (loc.IsUseful() && ShouldHilight()) {
      SetStateLabel("Useful");
    } else if (loc.IsTrap() && ShouldHilight()) {
      if (ap_show_traps == 0) {
        // Show traps as filler
        SetStateLabel("Filler");
      } else if (ap_show_traps == 2) {
        // Show traps as progression
        SetStateLabel("Progression");
      } else {
        SetStateLabel("Trap");
      }
    } else {
      SetStateLabel("Filler");
    }
  }

  // Implementing classes should define the following methods:
  //    abstract bool ShouldDisplay();
  // To determine whether to render at all;
  //    abstract bool ShouldHilight() { return true; }
  // To determine whether progression items should be marked as such;
  //    abstract bool IsTrigger() { return false; }
  // To determine if this is a trigger item that needs to be collectable even when empty.
}

// An automap marker. This is not tied to a CheckPickup and is used for marking
// secret sectors.
class ::CheckMapMarker : MapMarker {
  mixin ::ArchipelagoIcon;

  Default {
    Scale 0.25;
    // TODO: MapMarkers don't respect AutomapOffsets or A_SpriteOffset. If we
    // want them to display centered on the map, we need to give the sprite
    // itself centered offsets, and then A_SpriteOffset() on the in-world object
    // to keep it from clipping into the floor.
  }

  bool ShouldDisplay() {
    // 0 = never, 1 = if you have the automap, 2 = always.
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

  bool IsTrigger() { return false; }
}

// An automap marker tied to a CheckPickup. It follows the check around if it
// gets moved.
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
//
// These are initially created at level entry, one per physical Location. Once
// created, UpdateFromLocation() is called on each one to set its state based
// on the state of its backing location.
// This also happens whenever the level is re-entered, and individual checks
// will re-run it when the player touches them and they are marked collected.
class ::CheckPickup : ScoreItem {
  mixin ::ArchipelagoIcon;

  ::ItemMapMarker marker;
  ::CheckLabel label;
  ::CheckLabel orig_label;

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
      AP00 EEEEEEE 1 Subsume();
      AP00 E 1 NoOriginal();
      GOTO PostSpawn;
    PostSpawn:
      AP00 E 0 UpdateFromLocation();
      GOTO SetProgression;
  }

  static ::CheckPickup Create(::Location location) {
    let thing = ::CheckPickup(Actor.Spawn("::CheckPickup", location.pos));
    thing.location_id = location.apid;
    DEBUG("Check initialize: name=%s, ck=%d, flags=%1X",
      location.name, location.IsChecked(), location.flags);
    return thing;
  }

  bool ShouldDisplay() { return true; }
  bool ShouldHilight() {
    return ap_show_progression > 0;
  }

  // True if this check is associated with an action special or a TID and thus
  // might do something cool when picked up.
  // Checks with this property respawn when the level is re-entered (i.e. when
  // UpdateFromLocation() is called).
  bool IsTrigger() { return self.special || self.tid; }

  //// Initialization ////

  override void PostBeginPlay() {
    // Unreachables don't contribute towards the total check count.
    if (self.GetLocation().IsUnreachable()) self.ClearCounters();
  }

  void Subsume() {
    // Don't subsume if this is an unreachable check -- leave the original item
    // in place just in case.
    if (GetLocation().IsUnreachable()) return;
    DEBUG("Check[%s] Subsume", self.GetLocation().name);
    Actor closest;
    let it = BlockThingsIterator.Create(self, 32);
    while (it.Next()) {
      Actor thing = it.thing;
      if (thing is "::CheckPickup") continue;

      // TODO -- prefer things that match the recorded check category, if possible.
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
        DEBUG("Check[%s]: closest is %s (d=%f)", self.GetLocation().name, closest.GetClassName(), Distance3D(closest));
      }
    }

    if (!closest) return;
    if (Distance3D(closest) < 2.0) {
      UpdateFromOriginal(closest);
      closest.Destroy();
      SetStateLabel("PostSpawn");
    }
  }

  void NoOriginal() {
    DEBUG("Check[%s] couldn't find its original, imagining one instead", self.GetLocation().name);
    Class<Actor> cls = self.GetLocation().orig_typename;
    let orig = GetDefaultByType(cls);
    if (!orig) return;
    UpdateFromOriginal(orig);
  }

  void UpdateFromLocation() {
    let location = self.GetLocation();
    SetTag(location.name);
    if (self.IsTrigger()) {
      DEBUG("Check[%s]: is trigger, clearing checked bit", location.name);
      location.checked = false;
    }
    if (location.IsChecked()) {
      DEBUG("Check[%s] clearing markers", location.name);
      ClearMarkers();
    } else {
      DEBUG("Check[%s] creating markers", location.name);
      CreateMarkers();
    }
    A_SpriteOffset(0, -16);
  }

  void UpdateFromOriginal(readonly<Actor> original) {
    if (!original) return;
    // TODO: we should set a minimum radius here, to handle things like SCS cats,
    // which have a radius often too small to interact with because you're expected
    // to frob them rather than picking them up.
    // Alternately, we should allow overriding the radius in the GZAPRC.
    A_SetSize(original.radius, original.height);
    ChangeTID(original.TID);
    A_SetSpecial(original.special, original.args[0], original.args[1], original.args[2], original.args[3], original.args[4]);
    DEBUG("Check[%s] UpdateFromOriginal[%s] tid=%d special=%d", GetLocation().name,
      original.GetTag(), original.TID, original.special);
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
    DEBUG("Check[%s]: CreateLabel from %s", self.GetLocation().name, typename);

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
    label.frame = prototype.SpawnState.frame;
    label.parent = self;
    label.zoffs = zoffs;
    label.A_SetScale(scale);
    return label;
  }

  ::CheckLabel CreateIconLabel(string icon) {
    DEBUG("Check[%s]: CreateIconLabel(%s)", self.GetLocation().name, icon);
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
      DEBUG("Check[%s] spawning map marker", self.GetLocation().name);
      self.marker = ::ItemMapMarker(Spawn("::ItemMapMarker", self.pos));
      self.marker.parent = self;
      self.marker.location_id = self.location_id;
    }
    if (ap_show_check_contents && !self.label && !self.GetLocation().IsEmpty()) {
      self.label = CreateLabel(self.GetLocation().ap_typename);
    }
    if (ap_show_check_original && !self.orig_label && !::PlayEventHandler.Get().IsPretuning()) {
      self.orig_label = CreateLabel(self.GetLocation().orig_typename, 34);
    }
  }

  void ClearMarkers() {
    if (self.marker) self.marker.Destroy();
    if (self.label) self.label.Destroy();
    if (self.orig_label) self.orig_label.Destroy();
  }

  //// Pickup event handling ////

  override bool CanPickup(Actor toucher) {
    if (self.IsTrigger()) {
      // If it's a trigger object we always treat it as though ap_allow_collect
      // were off, to avoid softlocks.
      return !self.GetLocation().checked;
    }
    return !self.IsChecked();
  }

  override bool TryPickup (in out Actor toucher) {
    DEBUG("TryPickup: %s", self.GetLocation().name);
    // This will set the 'checked' flag and also, if necessary, send a message
    // to the client.
    ::PlayEventHandler.Get().CheckLocation(self.GetLocation());
    // Pretend that no item with this TID exists anymore. We'll respawn on level
    // reload if needed.
    // This is needed for compatibility with stuff like Square's vending
    // machines, which will only vend a new powerup if the old one no longer
    // exists on the map.
    ChangeTID(0);
    self.SetProgressionState();
    ClearMarkers();
    return true;
  }

  override bool ShouldStay() { return true; }

  override void OnDestroy() {
    ClearMarkers();
  }
}

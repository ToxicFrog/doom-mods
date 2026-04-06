// Information about a single AP Location.
//
// This class holds the out-of-world information about the location, sufficient
// to send and receive messages about it and track its state.
//
// At map load time, Locations are used to produce Checks; each Check is aware
// of the AP ID of its backing Location and derives its behaviour from that.

#namespace GZAP;
#debug off;

enum ::Tracking {
  AP_UNREACHABLE,     // Tracker thinks we can't get to this at all.
  AP_REACHABLE_OOL,   // Tracker thinks we can get to it physically but not logically (e.g. not enough guns)
  AP_REACHABLE_IL,    // Tracker thinks it's fully in logic.
}

enum ::LocationFlags {
  AP_IS_FILLER = 0,
  // These first three match the ItemClassification flags in AP
  AP_IS_PROGRESSION = 1,
  AP_IS_USEFUL = 2,
  AP_IS_TRAP = 4,
  AP_ITEMTYPE = 7,
  // These are internal to UZAP
  AP_IS_UNREACHABLE = 8,
  AP_IS_SECRET_TRIGGER = 16, // This secret uses a TID rather than a sector ID
  AP_IS_LOCAL = 32, // AP server doesn't know about this check
}

// A 'peek' delivered from AP, telling us what is at a given location and who
// it belongs to.
class ::Peek play {
  string player;
  string item;
}

// Information about a single check.
class ::Location abstract play {
  uint apid;
  string mapname;
  string name;           // Name of location
  string orig_typename;  // Typename of item this location originally held
  string ap_typename;    // Typename of item randomized here, for icon display
  ::LocationFlags flags; // As above
  ::Tracking track;   // Tracker status for this location
  ::Peek peek;

  // Flags for whether the check has been found locally and emptied remotely.
  // If both are false, the check hasn't been interacted with yet. If both are
  // true, the player has touched it and the server has acknowledged that.
  // If only checked is true, the player has touched it and we're still waiting
  // for the server to respond. If it has this state when we enter a level we
  // clear the checked bit and respawn it, on the assumption that the message
  // to the server got lost.
  // If only collected is true, the player hasn't found this check yet but it
  // was emptied server-side using !collect, so touching it will do nothing.
  bool checked;   // local
  bool collected; // remote

  // Called by the generated pk3 to perform non-subtype-specific-initialization,
  // i.e.
  // map.RegisterLocation(::LocationType.Create(...).Init(...))
  // The enclosing Region is responsible for setting the mapname field, everything
  // else is set either in Create or Init.
  ::Location Init(uint apid, string name, string orig_typename, string icon, uint flags) {
    self.apid = apid;
    self.name = name;
    self.orig_typename = orig_typename;
    self.ap_typename = icon;
    self.flags = flags;
    self.checked = false;
    self.collected = false;
    return self;
  }

  // If this returns true, the Region will register this for receipt of events
  // and call CheckEvent as appropriate.
  virtual bool IsEventBased() { return false; }
  // Called whenever a checkable event (level exit, secret discovery, etc)
  // occurs. event_type is always set. destination is set to the destination
  // level for exit events. thing is reserved for future use by spawn event
  // handlers.
  virtual void CheckEvent(string event_type, string destination, Actor thing) {
    DEBUG("CheckEvent(%s) for %s#%d", event_type, self.name, self.apid);
  }
  // Return the position in a format the apworld will understand.
  abstract string PositionJSON();
  // Called when the level is entered. If this is the first time (i.e. not a
  // savegame load or a reopen), first_time will be set.
  virtual void OnLevelEntry(bool first_time) {
    DEBUG("OnLevelEntry(%d) for %s#%d", first_time, self.name, self.apid);
  }

  // We consider two positions "close enough" to each other iff:
  // - d is less than MAX_DISTANCE, and
  // - only one of the coordinates differs.
  // This usually means an item placed on a conveyor or elevator configured to
  // start moving as soon as the level loads.
  static bool IsCloseEnough(Vector3 p, Vector3 q) {
    float MAX_DISTANCE = 2.0;
    Vector3 delta = p - q;
    return delta.length() <= MAX_DISTANCE
      && ((delta.x == 0 && delta.y == 0)
          || (delta.x == 0 && delta.z == 0)
          || (delta.y == 0 && delta.z == 0));
  }

  // Used when sorting the location list; should return true if self needs to
  // be ordered before other.
  bool Order(::Location other) {
    // Peeked locations are ordered before anything else.
    if (self.peek && !other.peek) {
      return true;
    } else if (!self.peek && other.peek) {
      return false;
    } else if (self.peek && other.peek) {
      // Both peeked? Prioritize progression > useful > everything else.
      if (self.ItemPriority() != other.ItemPriority()) {
        return self.ItemPriority() < other.ItemPriority();
      }
    }
    if (self.track != other.track) {
      // In-logic is always before OOL, which is always before unreachable.
      return self.track > other.track;
    }
    return self.name < other.name;
  }

  // TODO: pass through secret information from AP in a flag here
  bool IsSecret() const { return false; }

  // True if this location has been checked. By default this means *either* the
  // player has walked up to it and touched it *or* the server has remotely
  // collected it. Unsetting ap_allow_collect means only the player's actions
  // will be considered, and not the server.
  bool IsChecked() const {
    return self.checked || (ap_allow_collect && self.collected);
  }

  // True if the location's item has been collected by the server.
  bool IsEmpty() { return self.collected; }

  // True if the location is local-only, i.e. can be collected but should not
  // be reported to the server.
  bool IsLocal() const { return flags & AP_IS_LOCAL; }

  // True if the tuning file says this location can't be reached.
  bool IsUnreachable() const { return flags & AP_IS_UNREACHABLE; }

  // Standard AP item categories.
  bool IsFiller() { return (flags & AP_ITEMTYPE) == AP_IS_FILLER; }
  bool IsProgression() { return flags & AP_IS_PROGRESSION; }
  bool IsTrap() { return flags & AP_IS_TRAP; }
  bool IsUseful() { return flags & AP_IS_USEFUL; }

  // Numeric indicator of item category priority, lower == better.
  int ItemPriority() {
    if (IsProgression() && IsUseful()) {
      return 0;
    } else if (IsProgression()) {
      return 1;
    } else if (IsUseful()) {
      return 2;
    } else if (!IsTrap()) {
      return 3;
    } else {
      return 4;
    }
  }
}

class ::PhysicalLocation : ::Location {
  Vector3 pos;

  static ::PhysicalLocation Create(Vector3 pos) {
    let this = ::PhysicalLocation(new("::PhysicalLocation"));
    this.pos = pos;
    return this;
  }

  override void OnLevelEntry(bool first_time) {
    super.OnLevelEntry(first_time);
    ::CheckPickup.Create(self, self.pos);
  }

  override string PositionJSON() {
    return string.format("[\"%s\",%d,%d,%d]", self.mapname, self.pos.x, self.pos.y, self.pos.z);
  }
}

class ::EventLocation : ::Location abstract {
  override bool IsEventBased() { return true; }
}

class ::ExitLocation : ::EventLocation {
  string destination;

  static ::ExitLocation Create(string destination) {
    let this = ::ExitLocation(new("::ExitLocation"));
    this.destination = destination;
    return this;
  }

  override void CheckEvent(string event_type, string destination, Actor thing) {
    super.CheckEvent(event_type, destination, thing);
    if (event_type != "exit") return;
    if (self.destination && self.destination != destination) return;
    if (self.IsChecked()) return;
    ::PlayEventHandler.Get().CheckLocation(self, "Exit level "..self.mapname.." to "..destination);
  }

  override string PositionJSON() {
    if (self.destination) {
      return string.format("[\"%s\",\"exit\",\"%s\"]", self.mapname, self.destination);
    } else {
      return string.format("[\"%s\",\"exit\"]", self.mapname);
    }
  }
}

class ::SecretSectorLocation : ::EventLocation {
  int sector_id;

  static ::SecretSectorLocation Create(int sector_id) {
    let this = ::SecretSectorLocation(new("::SecretSectorLocation"));
    this.sector_id = sector_id;
    return this;
  }

  virtual bool IsSecret() { return true; }

  override void OnLevelEntry(bool first_time) {
    super.OnLevelEntry(first_time);
    let sector = level.sectors[self.sector_id];

    if (first_time) {
      let sector = level.sectors[self.sector_id];
      let marker = ::CheckMapMarker(Actor.Spawn(
        "::CheckMapMarker", (sector.centerspot.x, sector.centerspot.y, 0)));
      marker.location_id = self.apid;
    }

    // Location is checked but sector is still marked undiscovered -- level
    // probably got reset.
    if (self.IsChecked() && sector.IsSecret()) {
      DEBUG("Clearing secret flag on sector %d", self.sector_id);
      // UnmarkSecret(location);
      sector.ClearSecret();
      level.found_secrets++;
      return;
    }

    // Location isn't marked checked but the corresponding sector has been
    // discovered, so emit a check event for it.
    if (!self.IsChecked() && !sector.IsSecret()) {
      ::PlayEventHandler.Get().CheckLocation(self, "secret sector already discovered: "..self.sector_id);
      // UnmarkSecret(location);
      return;
    }

    // Player hasn't found this yet.
    if (!self.IsChecked()) {
      // self.secret_locations.Insert(location.secret_id, location);
      // MarkSecret(location);
    }
  }

  override void CheckEvent(string event_type, string destination, Actor thing) {
    super.CheckEvent(event_type, destination, thing);
    if (event_type != "secret") return;
    OnLevelEntry(false);
    if (self.IsChecked()) return;
    if (level.sectors[self.sector_id].IsSecret()) return;
    ::PlayEventHandler.Get().CheckLocation(self, "secret sector discovered: "..self.sector_id);
    // UnmarkSecret(location);
  }

  override string PositionJSON() {
    return string.format("[\"%s\",\"secret\",\"sector\",%d]", self.mapname, self.sector_id);
  }
}

class ::SecretTriggerLocation : ::EventLocation {
  int tid;

  static ::SecretTriggerLocation Create(int tid) {
    let this = ::SecretTriggerLocation(new("::SecretTriggerLocation"));
    this.tid = tid;
    return this;
  }

  override void OnLevelEntry(bool first_time) {
    super.OnLevelEntry(first_time);
    let iter = level.CreateActorIterator(self.tid, "SecretTrigger");

    // Location has already been checked in AP, remove the triggers.
    if (self.IsChecked()) {
      foreach (Actor trigger : iter) {
        trigger.Activate(trigger);
      }
      return;
    }

    // Location has not been checked. If the trigger is still in the map, that
    // means the player hasn't found this yet.
    if (iter.Next() != null) {
      // self.secret_locations.Insert(location.secret_id, location);
      return;
    }

    // Location not marked checked, but the trigger is gone, so the player must
    // have found it and we just didn't notice.
    DEBUG("%s has been checked, marking it off", self.name);
    ::PlayEventHandler.Get().CheckLocation(self, "secret trigger already fired: "..self.tid);
  }

  override void CheckEvent(string event_type, string destination, Actor thing) {
    super.CheckEvent(event_type, destination, thing);
    if (event_type != "secret") return;
    OnLevelEntry(false);
    if (self.IsChecked()) return;
    let iter = level.CreateActorIterator(self.tid, "SecretTrigger");
    if (iter.Next() != null) return; // Trigger object still exists
    ::PlayEventHandler.Get().CheckLocation(self, "secret trigger fired: "..self.tid);
  }

  override string PositionJSON() {
    return string.format("[\"%s\",\"secret\",\"tid\",%d]", self.mapname, self.tid);
  }
}

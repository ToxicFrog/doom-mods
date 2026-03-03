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
class ::Location {
  uint apid;
  string mapname;
  string name;
  string orig_typename;  // Typename of item this location originally held
  string ap_typename;    // Typename name of item randomized into this location
  string ap_name;        // User-facing name of same
  ::LocationFlags flags; // As above
  ::Tracking track;   // Tracker status for this location
  ::Peek peek;
  Vector3 pos;
  bool is_virt;       // Virtual location with no physical position.
  int secret_id;      // Either a sector ID or a TID depending

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
    }
    if (self.track != other.track) {
      // In-logic is always before OOL, which is always before unreachable.
      return self.track > other.track;
    }
    return self.name < other.name;
  }

  // TODO: pass through category information from the generated zscript, which
  // we can use for this and possibly for other stuff as well. We can't use the
  // orig_typename for this because some categories, like secret, depend on where
  // it was found, not what it is.
  bool IsSecret() {
    if (secret_id >= 0) return true;
    let sector = level.PointInSector((self.pos.x, self.pos.y));
    DEBUG("IsSecret(%s): (%d,%d) is=%d was=%d", self.name, self.pos.x, self.pos.y, sector.IsSecret(), sector.WasSecret());
    return sector.IsSecret() || sector.WasSecret();
  }

  // True if this location has been checked. By default this means *either* the
  // player has walked up to it and touched it *or* the server has remotely
  // collected it. Unsetting ap_allow_collect means only the player's actions
  // will be considered, and not the server.
  bool IsChecked() {
    return self.checked || (ap_allow_collect && self.collected);
  }

  // True if the location's item has been collected by the server.
  bool IsEmpty() { return self.collected; }

  // True if the location is local-only, i.e. can be collected but should not
  // be reported to the server.
  bool IsLocal() { return flags & AP_IS_LOCAL; }

  // Standard AP item categories.
  bool IsFiller() { return (flags & AP_ITEMTYPE) == AP_IS_FILLER; }
  bool IsProgression() { return flags & AP_IS_PROGRESSION; }
  bool IsTrap() { return flags & AP_IS_TRAP; }
  bool IsUseful() { return flags & AP_IS_USEFUL; }
  bool IsUnreachable() { return flags & AP_IS_UNREACHABLE; }
}

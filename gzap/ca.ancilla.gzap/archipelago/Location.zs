// Information about a single AP Location.
//
// At map load time, a Check is spawned for each Location that the player hasn't
// checked yet. This class holds out-of-world information about a single Location,
// sufficient to send and receive messages about it to AP and record its state.

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
  // These are internal to gzdoom
  AP_IS_UNREACHABLE = 8,
  AP_IS_SECRET_TRIGGER = 16, // This secret uses a TID rather than a sector ID
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
  bool checked;       // Has the player already checked it?
  ::Tracking track;   // Tracker status for this location
  Vector3 pos;
  bool is_virt;       // Virtual location with no physical position.
  int secret_id;      // Either a sector ID or a TID depending

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

  bool Order(::Location other) {
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

  bool IsFiller() { return flags == AP_IS_FILLER; }
  bool IsProgression() { return flags & AP_IS_PROGRESSION; }
  bool IsTrap() { return flags & AP_IS_TRAP; }
  bool IsUseful() { return flags & AP_IS_USEFUL; }
  bool IsUnreachable() { return flags & AP_IS_UNREACHABLE; }
}

// Information about a single AP Location.
//
// At map load time, a Check is spawned for each Location that the player hasn't
// checked yet. This class holds out-of-world information about a single Location,
// sufficient to send and receive messages about it to AP and record its state.

#namespace GZAP;
#debug on;

enum ::Tracking {
  AP_UNREACHABLE,     // Tracker thinks we can't get to this at all.
  AP_REACHABLE_OOL,   // Tracker thinks we can get to it physically but not logically (e.g. not enough guns)
  AP_REACHABLE_IL,    // Tracker thinks it's fully in logic.
}

// Information about a single check.
class ::Location {
  uint apid;
  string mapname;
  string name;
  string orig_typename;  // Typename of item this location originally held
  string ap_typename;    // Typename name of item randomized into this location
  string ap_name;        // User-facing name of same
  bool progression;   // Does it hold a progression item?
  bool unreachable;   // Do we think this is unreachable?
  bool checked;       // Has the player already checked it?
  ::Tracking track;   // Tracker status for this location
  Vector3 pos;
  bool is_virt;       // Virtual location with no physical position.
  int secret_sector;

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
}

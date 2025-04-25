// Information about a single AP Location.
//
// At map load time, a Check is spawned for each Location that the player hasn't
// checked yet. This class holds out-of-world information about a single Location,
// sufficient to send and receive messages about it to AP and record its state.

#namespace GZAP;
#debug on;

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
  bool in_logic;      // Does the tracker thing we can reach it?
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
    if (self.in_logic != other.in_logic) {
      // in-logic locations always sort before out-of-logic ones
      return self.in_logic;
    }
    return self.name < other.name;
  }
}

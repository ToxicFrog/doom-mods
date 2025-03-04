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
  string name;
  bool progression;   // Does it hold a progression item?
  bool unreachable;   // Do we think this is unreachable?
  bool checked;       // Has the player already checked it?
  Vector3 pos;
}

// Holds information about a single scanned location.
// Common superclass for scanned items and scanned monsters.

#namespace GZAP;

class ::ScannedLocation abstract play {
  string mapname;
  Vector3 pos;
  string typename;
  // Spawn filter for this location. Bitmask.
  uint filter;

  abstract void Output(int spawn_filter);

  string OutputPosition() {
    return string.format("\"pos\": [\"%s\",%d,%d,%d]",
      mapname, round(pos.x), round(pos.y), round(pos.z));
  }

  string OutputSkill(int spawn_filter) {
    // Omit field entirely for "available on all skills".
    if (spawn_filter == self.filter) return "";
    return string.format("\"filter\": %d, ", self.filter);
  }

  bool HasSkill(int sf) {
    return (sf & self.filter) != 0;
  }

  void AddSkill(int sf) {
    self.filter |= sf;
  }
}

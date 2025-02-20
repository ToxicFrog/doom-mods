// Holds information about a single scanned location.
// Common superclass for scanned items and scanned monsters.

#namespace GZAP;

class ::ScannedLocation abstract play {
  Vector3 pos;

  abstract void Output(string mapname);

  string OutputPosition() {
    return string.format(
      "\"position\": { \"x\": %f, \"y\": %f, \"z\": %f }",
      pos.x, pos.y, pos.z);
  }

}

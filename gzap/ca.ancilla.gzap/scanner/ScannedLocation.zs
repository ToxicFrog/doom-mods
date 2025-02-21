// Holds information about a single scanned location.
// Common superclass for scanned items and scanned monsters.

#namespace GZAP;

class ::ScannedLocation abstract play {
  Vector3 pos;
  string typename;
  // Which skills this location is valid on.
  // Since skill 0 (ITYTD) uses the same actor placement as HNTR, and likewise
  // for NM! and UV, the only skills we track are 1 (HNTR), 2 (HMP), and 3 (UV).
  Array<int> skill;

  abstract void Output(string mapname);

  string OutputPosition() {
    return string.format(
      "\"position\": { \"x\": %f, \"y\": %f, \"z\": %f }",
      pos.x, pos.y, pos.z);
  }

  string OutputSkill() {
    // Omit field entirely for "available on all skills".
    if (HasSkill(1) && HasSkill(2) && HasSkill(3)) return "";
    string buf = "";
    foreach (sk : skill) {
      buf = string.format("%s%s%d", buf, buf == "" ? "" : ", ", sk);
    }
    return string.format("\"skill\": [%s], ", buf);
  }

  bool HasSkill(int sk) {
    return skill.Find(sk) != skill.Size();
  }

  void AddSkill(int sk) {
    if (HasSkill(sk)) return;
    skill.Push(sk);
  }
}

#namespace TFIS;
#debug off;

class ::Util {
  static int GetInt(string name) {
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetInt();
    return -1;
  }

  static bool GetBool(string name) {
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetBool();
    return false;
  }
}

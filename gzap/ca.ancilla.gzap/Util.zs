#namespace GZAP;

class ::Util play {
  // Eurgh this is gross, but zscript doesn't let us have va_list so...
  static void printf(string msg, string arg1 = "", string arg2 = "", string arg3 = "") {
    console.printf(
      StringTable.Localize(msg),
      StringTable.Localize(arg1),
      StringTable.Localize(arg2),
      StringTable.Localize(arg3));
  }

  static void announce(string msg, string arg1 = "", string arg2 = "", string arg3 = "") {
    if (!::PlayEventHandler.Get().IsSingleplayer()) {
      return;
    }

    ::Util.printf(msg, arg1, arg2, arg3);
  }

  static string bool2str(bool b) {
    return b ? "true" : "false";
  }

  static int GetSkill() {
    return G_SkillPropertyInt(SKILLP_ACSReturn);
  }

  static string GetSkillName() {
    int sk = ::Util.GetSkill();
    switch (sk) {
      case 0: return "ITYTD";
      case 1: return "HNTR";
      case 2: return "HMP";
      case 3: return "UV";
      case 4: return "NM!";
      default: return "???";
    }
  }
}

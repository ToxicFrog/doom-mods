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

  clearscope static string join(string sep, Array<string> xs) {
    if (xs.Size() == 0) {
      return "";
    }
    string buf = xs[0];
    for (int i = 1; i < xs.Size(); ++i) {
      buf.AppendFormat("%s%s", sep, xs[i]);
    }
    return buf;
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

  static clearscope int GetCurrentFilter() {
    return G_SkillPropertyInt(SKILLP_SpawnFilter);
  }

  static clearscope string GetFilterName(int filter) {
    switch (filter) {
      // Internally, gzdoom distinguishes all five difficulty levels. However,
      // in practice, almost no WADs make use of ITYTD or NM for thing placement,
      // so (at least for now) we make the simplifying assumption that ITYTD==HNTR
      // and UV==NM.
      case 1:
      case 2:
        return "easy";
      case 4:
        return "medium";
      case 8:
      case 16:
        return "hard";
      default:
        return string.format("unknown (0x%02X)", filter);
    }
  }

  // Very simple glob matcher. Only supports exact matches, * at the front, *
  // at the back, or * in both.
  static clearscope bool GlobMatch(string glob, string buf) {
    bool is_prefix, is_suffix;
    if (glob.Left(1) == "*") {
      is_suffix = true;
      glob = glob.Mid(1).MakeLower();
    }
    if (glob.Mid(glob.Length()-1) == "*") {
      is_prefix = true;
      glob.DeleteLastCharacter();
    }

    if (glob.Length() > buf.Length()) return false;

    if (is_prefix && is_suffix) {
      return buf.MakeLower().IndexOf(glob) >= 0;
    } else if (is_suffix) {
      return buf.MakeLower().Mid(buf.Length() - glob.Length()) == glob;
    } else if (is_prefix) {
      return buf.Left(glob.Length()) == glob;
    } else {
      return buf == glob;
    }
  }

  static clearscope string GetKeyColour(string keyname, string backup) {
    string keyname = keyname.MakeLower();
    static const string[] keycolours = { "red", "orange", "yellow", "green", "blue", "purple" };

    for (int i=0; i < keycolours.Size(); ++i) {
      if (keyname.IndexOf(keycolours[i]) != -1) {
        return keycolours[i];
      }
    }

    return backup;
  }
}

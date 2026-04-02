#namespace GZAP;

class ::StringSet {
  // We make it a map of items to themselves, because iterating over it like
  // foreach (k : contents) returns the values, not the keys.
  Map<string, string> contents;

  static ::StringSet Create() {
    return new("::StringSet");
  }

  void Insert(string item) { self.contents.Insert(item, item); }
  void Remove(string item) { self.contents.Remove(item); }
  void Clear() { self.contents.Clear(); }
  bool Contains(string item) { return self.contents.CheckKey(item); }
  bool Size() { return self.contents.CountUsed(); }
  string Join(string sep) {
    if (self.Size() == 0) return "";
    string buf = "";
    foreach (k : self.contents) {
      buf.AppendFormat("%s%s", buf == "" ? "" : sep, k);
    }
    return buf;
  }
}

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
      default: return string.format("?%d?", sk);
    }
  }

  static clearscope int GetSpawnFilter() {
    return G_SkillPropertyInt(SKILLP_SpawnFilter);
  }

  static clearscope int GetSpawnFilterIndex() {
    // The filter is stored as a bitmask; in play exactly one bit will be set
    // so it can be &ed with the bitmasks in the map data. The filter index is
    // the *1-indexed* position of the set bit.
    switch (GetSpawnFilter()) {
      case 1: return 1;
      case 2: return 2;
      case 4: return 3;
      case 8: return 4;
      case 16: return 5;
      case 32: return 6;
      case 64: return 7;
      case 128: return 8;
      default: return -1;
    }
  }

  static clearscope string GetFilterName(int filter_index) {
    switch (filter_index) {
      case 1: return "ITYTD";
      case 2: return "HNTR";
      case 3: return "HMP";
      case 4: return "UV";
      case 5: return "NM";
      case 6: return "skill6";
      case 7: return "skill7";
      case 8: return "skill8";
      default:
        return string.format("unknown (0x%02X)", filter_index);
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

  // TODO: move this into python? or GZAPRC?
  static clearscope string GetKeyColour(string keyname, string backup) {
    string keyname = keyname.MakeLower();

    Map<string, string> colours;
    if (colours.CountUsed() == 0) {
      // Red
      colours.Insert("red", "red");
      colours.Insert("ruby", "red");
      colours.Insert("circlekey", "red");
      colours.Insert("spherekey", "red");
      colours.Insert("crescentrune", "red");
      // Orange
      colours.Insert("orange", "orange");
      // Yellow
      colours.Insert("yellow", "yellow");
      colours.Insert("topaz", "yellow");
      colours.Insert("trianglekey", "yellow");
      colours.Insert("pyramidkey", "yellow");
      colours.Insert("starrune", "yellow");
      // Green
      colours.Insert("green", "green");
      colours.Insert("emerald", "green");
      colours.Insert("trapezoidkey", "green");
      // Cyan
      colours.Insert("cyan", "cyan");
      colours.Insert("hexagonkey", "cyan");
      // Blue
      colours.Insert("blue", "blue");
      colours.Insert("sapphire", "blue");
      colours.Insert("rhombuskey", "blue");
      // Purple
      colours.Insert("purple", "purple");
      colours.Insert("amethyst", "purple");
      colours.Insert("squarekey", "purple");
      colours.Insert("cubekey", "purple");
      colours.Insert("diamondrune", "purple");
      colours.Insert("pink", "purple");
      // Grey
      colours.Insert("floppydisk", "grey");
      colours.Insert("gear", "grey");
      // Miscellaneous
      colours.Insert("gold", "gold");
      colours.Insert("silver", "ice");
    }

    foreach (name, colour : colours) {
      if (keyname.IndexOf(name) != -1) {
        return colour;
      }
    }

    return backup;
  }

  static clearscope int HubIndex() {
    for (int i = 0; i < LevelInfo.GetLevelInfoCount(); ++i) {
      let info = LevelInfo.GetLevelInfo(i);
      if (info && info.MapName == "GZAPHUB") return i;
    }
    return 0;
  }

  static clearscope string FormatHint(string player, string location) {
    let slot_name = ::RandoState.Get().slot_name;
    return string.format("\c-⌖ %s @ %s", player, location);
  }

  static clearscope string FormatPeek(string player, string item, uint flags) {
    let slot_name = ::RandoState.Get().slot_name;
    return string.format("\c-ⓘ %s for %s", item, player);
  }

  static Actor SpawnUnrestricted(readonly<Actor> parent, class<Actor> typename, int flags) {
    Actor child;
    let plh = ::PerLevelHandler.Get();
    if (plh.disable_actor_replacement) {
      child = parent.Spawn(typename, parent.pos, flags);
    } else {
      plh.DisableActorReplacement();
      child = parent.Spawn(typename, parent.pos, flags);
      plh.EnableActorReplacement();
    }
    return child;
  }
}

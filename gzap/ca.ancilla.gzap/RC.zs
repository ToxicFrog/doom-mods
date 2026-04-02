// Loader for the GZAPRC lump, including lump parser. See end of file for the
// formal grammar, and the included GZAPRC for a working example.
// This is the file that controls per-wad settings for UZArchipelago. At present
// this just means the scanner.
#namespace GZAP;
#debug off;

class ::RC {
  static ::RC Get() {
    let seh = ::ScanEventHandler(StaticEventHandler.Find("::ScanEventHandler"));
    if (!seh) return null;
    return seh.rc;
  }

  static ::RC Create() {
    let rc = ::RC(new("::RC"));
    rc.destroy_on_spawn = ::StringSet.Create();
    return rc;
  }

  static ::RC LoadAll(string lumpname) {
    let rc = ::RC.Create();
    let parser = ::RCParser(new("::RCParser"));
    int lump = wads.FindLump(lumpname, 0, wads.AnyNamespace);
    while (lump >= 0) {
      let tmp = parser.Parse(wads.ReadLump(lump));
      if (!tmp) {
        console.printf("\c[RED][AP] Error loading config file %s#%d.", wads.GetLumpFullName(lump), lump);
      } else if (tmp.has_requirements && tmp.should_skip) {
        console.printf("[AP] Skipping config file %s#%d (wrong megawad).", wads.GetLumpFullName(lump), lump);
      } else {
        console.printf("\c[CYAN][AP] Loaded config file %s#%d.", wads.GetLumpFullName(lump), lump);
        rc.merge(tmp);
      }
      lump = wads.FindLump(lumpname, lump+1, wads.AnyNamespace);
    }
    // rc.DebugPrint();
    return rc;
  }

  Map<string, string> categorizations;
  Map<string, string> typenames;
  ::StringSet destroy_on_spawn;
  Map<string, string> tags;
  Map<string, string> scanner_settings;
  Map<int, string> cluster_names;
  Map<string, ::StringSet> prereqs;
  void merge(::RC other) {
    foreach (k, v : other.categorizations) {
      SetCategory(k, v);
    }
    foreach (k, v : other.typenames) {
      SetTypename(k, v);
    }
    foreach (k : other.destroy_on_spawn.contents) {
      SetDestroyOnSpawn(k);
    }
    foreach (k, v : other.tags) {
      SetActorTag(k, v);
    }
    foreach (k, v : other.scanner_settings) {
      self.scanner_settings.Insert(k, v);
    }
    foreach (k, v : other.cluster_names) {
      self.SetClusterName(k, v);
    }
    foreach (k, v : other.prereqs) {
      let prereq_set = PrereqsFor(k);
      foreach (prereq : v.contents) {
        prereq_set.Insert(prereq);
      }
    }
  }

  void DebugPrint() {
    console.printf("Parsed GZAPRC contents:");
    if (self.scanner_settings.CountUsed() > 0) {
      console.printf("  scanner {");
      foreach (k,v : self.scanner_settings) {
        console.printf("    %s %s;", k, v);
      }
      console.printf("  }");
    }
    if (self.destroy_on_spawn.Size() > 0) {
      console.printf("  destroy-on-spawn %s;", self.destroy_on_spawn.Join(" "));
    }
    if (self.prereqs.CountUsed() > 0) {
      console.printf("  prereqs {");
      foreach (k,v : self.prereqs) {
        if (k == "*") {
          console.printf("    all: %s;", v.Join(" "));
        } else if (k.Left(4) == "map/") {
          console.printf("    %s: %s;", k.Mid(4), v.Join(" "));
        } else {
          console.printf("    %s: %s;", k.Mid(6), v.Join(" "));
        }
      }
      console.printf("  }");
    }
    foreach (k,v : self.cluster_names) {
      console.printf("  cluster %d %s;", k, v);
    }
    foreach (k,v : self.categorizations) {
      console.printf("  category %s: %s;", v == "" ? "none" : v, k);
    }
    foreach (k,v : self.typenames) {
      console.printf("  typename %s: %s;", v, k);
    }
    foreach (k,v : self.tags) {
      console.printf("  tag %s %s;", k, v);
    }
  }

  ::StringSet PrereqsFor(string k) {
    if (self.prereqs.CheckKey(k)) {
      return self.prereqs.Get(k);
    } else {
      let sset = ::StringSet.Create();
      self.prereqs.Insert(k, sset);
      return sset;
    }
  }

  void ApplyScannerSettings() {
    if (self.scanner_settings.CountUsed() == 0) return;
    console.printf("[AP] Applying default scanner settings from GZAPRC lumps:");
    foreach (k, v : self.scanner_settings) {
      console.printf("[AP]   %s = %s", k, v);
      let cv = CVar.FindCVar(k);
      if (cv.GetRealType() == CVAR.CVAR_Bool) {
        cv.SetBool(v == "true");
      } else if (cv.GetRealType() == CVAR.CVAR_String) {
        cv.SetString(v);
      }
    }
  }

  void SetCategory(string cls, string category) {
    if (category == "none") category = "";
    DEBUG("Set category for %s to %s", cls, category);
    self.categorizations.Insert(cls.MakeLower(), category);
  }

  string, bool GetCategory(string cls) {
    let [val, ok] = self.categorizations.CheckValue(cls.MakeLower());
    return val, ok;
  }

  void SetTypename(string cls, string typename) {
    DEBUG("Set typename for %s to %s", cls, typename);
    self.typenames.Insert(cls.MakeLower(), typename);
  }

  string, bool GetTypename(string cls) {
    let [val, ok] = self.typenames.CheckValue(cls.MakeLower());
    return val, ok;
  }

  void SetDestroyOnSpawn(string cls) {
    self.destroy_on_spawn.Insert(cls.MakeLower());
  }

  bool GetDestroyOnSpawn(string cls) {
    return self.destroy_on_spawn.Contains(cls.MakeLower());
  }

  void SetActorTag(string cls, string tag) {
    DEBUG("Set tag for %s to %s", cls, tag);
    self.tags.insert(cls.MakeLower(), tag);
  }

  string GetTag(readonly<Actor> act) {
    string cls = act.GetClassName();
    let tag = self.tags.GetIfExists(cls.MakeLower());
    if (tag) return tag;
    return act.GetTag();
  }

  void SetClusterName(int cluster, string name) {
    DEBUG("Set cluster name for id %d to %s", cluster, name);
    self.cluster_names.Insert(cluster, name);
  }

  string GetNameForCluster(int cluster) {
    if (cluster == 0) return "";
    if (self.cluster_names.CheckKey(cluster)) {
      return self.cluster_names.GetIfExists(cluster);
    }
    return string.format("HUB:%02d", cluster);
  }

  bool has_requirements;
  bool should_skip;
  void CheckRequiredMap(string mapname, string checksum) {
    if (!has_requirements) {
      self.has_requirements = true;
      self.should_skip = true;
    }
    if (LevelInfo.MapChecksum(mapname) == checksum) {
      self.should_skip = false;
    }
  }

  ::StringSet GetPrereqsForMap(string map, Map<string, int> actors) {
    let sset = ::StringSet.Create();
    if (self.prereqs.CheckKey("*")) {
      sset.UnionFrom(self.prereqs.Get("*"));
    }
    if (self.prereqs.CheckKey("map/"..map)) {
      sset.UnionFrom(self.prereqs.Get("map/"..map));
    }
    // There is an infelicity in zscript here: if the map is local or an instance
    // variable, we can foreach on the map directly, but if it is a function
    // argument, it has type pointer<map<K,V>> and we need to manually construct
    // the MapIterator.
    MapIterator<string, int> it;
    it.Init(actors);
    foreach (typename, count : it) {
      if (self.prereqs.CheckKey("actor/"..typename)) {
        sset.UnionFrom(self.prereqs.Get("actor/"..typename));
      }
    }
    return sset;
  }
}

class ::RCParser {
  ::RC rc;
  array<string> lines; int line;
  array<string> tokens; int token;

  ::RC Parse(string lump) {
    self.rc = ::RC.Create();
    lines.clear(); tokens.clear();
    lump.split(lines, "\n", true);
    line = 0; token = 0;

    if (!Statements()) return null;
    return rc;
  }

  bool hasTokens() {
    while (token < tokens.size() && tokens[token] == "") ++token;
    // DEBUG("hasTokens? t=%d n=%d head=[%s] %d",
    //   token, tokens.size(),
    //   token < tokens.size() ? tokens[token] : "$",
    //   token < tokens.size() ? tokens[token] == "" : -1);
    return token < tokens.size() && tokens[token] != '#';
  }

  bool ensureTokens() {
    // Keep trying until we successfully fill the token buffer.
    while (!hasTokens()) {
      // Give up if we empty the line buffer.
      if (line >= lines.size()) return false;
      // Read in and tokenize the next line
      string buf = lines[line++];
      // DEBUG("ensureTokens: [%s]", buf);
      // Convert tabs to spaces and surround punctuation with whitespace...
      buf.replace("\t", " ");
      buf.replace("\r", "");
      buf.replace("{", " { ");
      buf.replace("}", " } ");
      buf.replace("#", " # ");
      buf.replace(":", " : ");
      buf.replace(";", " ; ");
      // ...so we can then split on spaces.
      tokens.clear();
      buf.split(tokens, " ", false);
      token = 0;
      // DEBUG("ensuretokens: %d", tokens.size());
      // Loop continues because this line might be comment or blank.
    }
    return true;
  }

  // If the next token exactly matches token, return true. Does not consume the
  // token.
  bool peek(string expected) {
    if (!ensureTokens()) return false;
    DEBUG("peek: %s (%s)", tokens[token], expected);
    return tokens[token] == expected;
  }

  // As peek, but consume the token and reports an error if it doesn"t match.
  bool require(string expected) {
    if (!ensureTokens()) return false;
    DEBUG("require: %s (%s)", tokens[token], expected);
    if (!peek(expected)) return Error(expected);
    ++token;
    return true;
  }

  // Return the next token in the buffer. Report an error using the given
  // expectation at EOF, and return the empty string.
  string next(string expected) {
    if (!ensureTokens()) {
      Error(expected);
      return "";
    }
    DEBUG("next: %s (%s)", tokens[token], expected);
    return tokens[token++];
  }

  // Report an error at the current parsing position.
  bool Error(string expected) {
    console.printf("\c[RED]Error parsing GZAPRC line %d: expected %s, got %s",
      line+1, expected, ErrorContext());
    return false;
  }
  bool ErrorNoExpectation(string err) {
    console.printf("\c[RED]Error parsing GZAPRC line %d: %s",
      line+1, err);
    return false;
  }

  string ErrorContext() {
    if (token < tokens.size()) return "'"..tokens[token].."'";
    return "end-of-file";
  }

  bool Statements() {
    while (ensureTokens()) { if (!Statement()) return false; }
    return true;
  }

  bool Statement() {
    if (peek("category")) { return ActorCategory(); }
    if (peek("typename")) { return ActorTypename(); }
    if (peek("destroy-on-spawn")) { return ActorDestroyOnSpawn(); }
    if (peek("tag")) { return ActorTag(); }
    if (peek("require")) { return Requirements(); }
    if (peek("scanner")) { return ScannerConfig(); }
    if (peek("cluster")) { return ClusterName(); }
    if (peek("prereqs")) { return PrereqRules(); }
    else { return Error("start of configuration directive"); }
  }

  bool ActorCategory() {
    require("category");
    Array<string> categories;
    if (!TokenList(categories, ":", "category")) return false;
    if (categories.size() != 1) return Error("exactly one category");

    Array<string> classes;
    if (!ClassList(classes, ";")) return false;
    if (classes.size() == 0) return Error("list of classes to categorize");

    foreach (cls : classes) {
      self.rc.SetCategory(cls, categories[0]);
    }
    return true;
  }

  bool ActorTypename() {
    require("typename");
    Array<string> types;
    if (!ClassList(types, ":")) return false;
    if (types.size() != 1) return Error("exactly one typename");

    Array<string> classes;
    if (!ClassList(classes, ";")) return false;
    if (classes.size() == 0) return Error("list of classes to remap");

    foreach (cls : classes) {
      self.rc.SetTypename(cls, types[0]);
    }
    return true;
  }

  bool ActorDestroyOnSpawn() {
    require("destroy-on-spawn");
    Array<string> classes;
    if (!ClassList(classes, ";")) return false;
    if (classes.size() == 0) return Error("one or more typenames");

    foreach (cls : classes) {
      self.rc.SetDestroyOnSpawn(cls);
    }

    return true;
  }

  bool ActorTag() {
    if (!require("tag")) return false;
    string actor_type = next("actor type");
    if (!actor_type) return Error("actor typename");
    string tag = StringFromTokenList(";", "actor tag");
    if (tag == "") return Error("non-empty user-facing actor tag");
    self.rc.SetActorTag(actor_type, tag);
    return true;
  }

  bool Requirements() {
    if (!require("require")) return false;
    string mapname = next("map name");
    if (mapname == "") return false;
    string checksum = next("map checksum");
    if (checksum == "") return false;
    if (!require(";")) return false;
    self.rc.CheckRequiredMap(mapname, checksum);
    return true;
  }

  bool ScannerConfig() {
    if (!require("scanner") || !require("{")) return false;
    while (!peek("}")) {
      string suffix = next("scanner setting name");
      string cvname = "ap_scan_" .. suffix;
      let cv = CVar.FindCVar(cvname);
      if (!cv) {
        return ErrorNoExpectation("Unknown scanner cvar " .. cvname);
      }

      if (cv.GetRealType() == CVar.CVAR_Bool) {
        if (peek("false") || peek("true")) {
          rc.scanner_settings.Insert(cvname, next("boolean"));
          require(";");
        } else {
          return require("true or false");
        }

      } else if (cv.GetRealType() == CVar.CVAR_String) {
        let val = StringFromTokenList(";", "scanner settings");
        if (val == "") return false;
        rc.scanner_settings.Insert(cvname, val);

      } else {
        return ErrorNoExpectation("Unsupported cvar type for scanner cvar " .. cvname);
      }
    }
    return require("}");
  }

  bool ClusterName() {
    if (!require("cluster")) return false;
    int cluster = next("cluster id").ToInt();
    if (cluster <= 0) return Error("numeric cluster id");
    string name = StringFromTokenList(";", "cluster name");
    if (name == "") return Error("non-empty cluster name");
    self.rc.SetClusterName(cluster, name);
    return true;
  }

  bool PrereqRules() {
    if (!require("prereqs") || !require("{")) return false;
    while (!peek("}")) {
      if (peek("all")) {
        if (!PrereqsForAll()) return false;
      } else if (peek("map")) {
        if (!PrereqsForMaps()) return false;
      } else if (peek("actor")) {
        if (!PrereqsForActors()) return false;
      } else {
        return Error("'actor', 'map', or 'all'");
      }
    }
    return require("}");
  }

  void InsertPrereqs(string scope, Array<string> prereqs) {
    let prereq_set = self.rc.PrereqsFor(scope);
    foreach (prereq : prereqs) {
      prereq_set.Insert(prereq);
    }
  }

  bool PrereqsForAll() {
    if (!require("all") || !require(":")) return false;

    Array<string> prereqs;
    if (!TokenList(prereqs, ";", "non-empty prereq list")) return false;
    if (prereqs.size() == 0) return Error("non-empty prereq list");

    InsertPrereqs("*", prereqs);
    return true;
  }

  bool PrereqsForMaps() {
    if (!require("map")) return false;

    Array<string> maps;
    if (!TokenList(maps, ":", "non-empty list of maps")) return false;
    if (maps.size() == 0) return Error("non-empty list of maps");

    Array<string> prereqs;
    if (!TokenList(prereqs, ";", "non-empty prereq list")) return false;
    if (prereqs.size() == 0) return Error("non-empty prereq list");

    foreach (map : maps) {
      InsertPrereqs("map/"..map, prereqs);
    }
    return true;
  }

  bool PrereqsForActors() {
    if (!require("actor")) return false;

    Array<string> types;
    if (!ClassList(types, ":")) return false;
    if (types.size() == 0) return Error("non-empty list of actor types");

    Array<string> prereqs;
    if (!TokenList(prereqs, ";", "non-empty prereq list")) return false;
    if (prereqs.size() == 0) return Error("non-empty prereq list");

    foreach (type : types) {
      InsertPrereqs("actor/"..type, prereqs);
    }
    return true;
  }

  bool ClassList(array<string> tokens, string terminator) {
    return TokenList(tokens, terminator, "class name");
  }
  bool PatternList(array<string> tokens, string terminator) {
    return TokenList(tokens, terminator, "class name or prefix");
  }
  bool TokenList(array<string> tokens, string terminator, string expected) {
    while (!peek(terminator)) {
      string buf = next(expected);
      if (buf == "") return false; // error already reported by next()
      if (buf == ";" || buf == ":" || buf == "{" || buf == "}")
        return Error(expected);
      tokens.push(buf);
    }
    require(terminator);
    return true;
  }
  string StringFromTokenList(string terminator, string expected) {
    array<string> tokens;
    if (!TokenList(tokens, terminator, expected)) return "";
    return ::Util.join(" ", tokens);
  }
}

// Lump grammar:
//             rc := statement*
//      statement := comment | itemcategory | itemtype
//        comment := '#' SINGLELINE EOL
//   itemcategory := 'category' CATEGORYNAME ':' CLASSNAME+ ';'
//       itemtype := 'typename' CLASSNAME ':' CLASSNAME+ ';'

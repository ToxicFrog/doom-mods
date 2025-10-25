// Loader for the GZAPRC lump, including lump parser. See end of file for the
// formal grammar, and the included GZAPRC for a working example.
// This is the file that controls per-wad settings for gzArchipelago. At present
// this just means the scanner.
#namespace GZAP;
#debug off;

class ::RC : Object play {
  static ::RC Get() {
    let seh = ::ScanEventHandler(StaticEventHandler.Find("::ScanEventHandler"));
    if (!seh) return null;
    return seh.rc;
  }

  static ::RC LoadAll(string lumpname) {
    let rc = ::RC(new("::RC"));
    let parser = ::RCParser(new("::RCParser"));
    int lump = wads.FindLump(lumpname, 0, wads.AnyNamespace);
    while (lump >= 0) {
      let tmp = parser.Parse(wads.ReadLump(lump));
      if (!tmp) {
        console.printf("\c[RED][AP] Error loading config file %s#%d.", wads.GetLumpFullName(lump), lump);
      } else if (tmp.has_requirements && tmp.should_skip) {
        console.printf("[AP] Skipping config file %s#%d (wrong megawad).", wads.GetLumpFullName(lump), lump);
      } else {
        console.printf("[AP] Loaded config file %s#%d.", wads.GetLumpFullName(lump), lump);
        rc.merge(tmp);
      }
      lump = wads.FindLump(lumpname, lump+1, wads.AnyNamespace);
    }
    return rc;
  }

  Map<string, string> categorizations;
  Map<string, string> typenames;
  Map<string, string> scanner_settings;
  Map<int, string> cluster_names;
  void merge(::RC other) {
    foreach (k, v : other.categorizations) {
      SetCategory(k, v);
    }
    foreach (k, v : other.typenames) {
      SetTypename(k, v);
    }
    foreach (k, v : other.scanner_settings) {
      self.scanner_settings.Insert(k, v);
    }
    foreach (k, v : other.cluster_names) {
      self.SetClusterName(k, v);
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
    self.categorizations.Insert(cls, category);
  }

  string, bool GetCategory(string cls) {
    let [val, ok] = self.categorizations.CheckValue(cls);
    return val, ok;
  }

  void SetTypename(string cls, string typename) {
    DEBUG("Set typename for %s to %s", cls, typename);
    self.typenames.Insert(cls, typename);
  }

  string, bool GetTypename(string cls) {
    let [val, ok] = self.typenames.CheckValue(cls);
    return val, ok;
  }

  void SetClusterName(int cluster, string name) {
    self.cluster_names.Insert(cluster, name);
  }

  string GetNameForCluster(int cluster) {
    if (self.cluster_names.CheckKey(cluster)) {
      return self.cluster_names.GetIfExists(cluster);
    }
    return "";
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
}

class ::RCParser : Object play {
  ::RC rc;
  array<string> lines; int line;
  array<string> tokens; int token;

  ::RC Parse(string lump) {
    self.rc = ::RC(new("::RC"));
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
    if (peek("require")) { return Requirements(); }
    if (peek("scanner")) { return ScannerConfig(); }
    if (peek("cluster")) { return ClusterName(); }
    else { return Error("category or typename directive"); }
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

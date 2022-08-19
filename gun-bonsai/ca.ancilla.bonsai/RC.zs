// Loader for the BONSAIRC lump, including lump parser. See end of file for the
// formal grammar, and the included BONSAIRC for a working example.
#namespace TFLV;
#debug off;

enum ::WeaponType {
  ::TYPE_AUTO       = 0x00,
  ::TYPE_IGNORE     = 1<<0,
  ::TYPE_MELEE      = 1<<1,
  ::TYPE_HITSCAN    = 1<<2,
  ::TYPE_PROJECTILE = 1<<3,
  ::TYPE_FASTPROJECTILE = 1<<4,
  ::TYPE_SEEKER     = 1<<5,
  ::TYPE_RIPPER     = 1<<6,
  ::TYPE_BOUNCER    = 1<<7,
}

class ::RC : Object play {
  static ::RC GetRC() {
    let seh = ::EventHandler(StaticEventHandler.Find("::EventHandler"));
    if (!seh) return null;
    return seh.rc;
  }

  static ::RC LoadAll(string lumpname) {
    let rc = ::RC(new("::RC"));
    let parser = ::RCParser(new("::RCParser"));
    int lump = wads.FindLump(lumpname, 0, wads.GlobalNamespace);
    while (lump >= 0) {
      let tmp = parser.Parse(wads.ReadLump(lump));
      if (tmp) {
        rc.nodes.append(tmp.nodes);
      } else {
        console.printf("\c[RED]Error loading lump %d (%s), skipping.", lump, wads.GetLumpFullName(lump));
      }
      lump = wads.FindLump(lumpname, lump+1, wads.GlobalNamespace);
    }
    return rc;
  }

  array<::RC::Node> nodes;
  void push(::RC::Node node) {
    nodes.push(node);
  }

  void Finalize(::EventHandler handler) {
    DEBUG("Finalize: %s", self.GetClassName());
    for (uint i = 0; i < nodes.size(); ++i) {
      DEBUG("Finalize: %s", nodes[i].GetClassName());
      nodes[i].Finalize(handler);
    }
  }

  void Configure(::WeaponInfo info) {
    DEBUG("Configure: %s", info.wpnClass);
    for (uint i = 0; i < nodes.size(); ++i) {
      nodes[i].Configure(info);
    }
  }
}

// Individual AST node types.
class ::RC::Node : Object play {
  virtual void Finalize(::EventHandler handler) {}
  virtual void Configure(::WeaponInfo info) {}

  static void ValidateUpgrades(array<string> upgrades) {
    array<string> real;
    for (uint i = 0; i < upgrades.size(); ++i) {
      let cls = (Class<::Upgrade::BaseUpgrade>)(upgrades[i]);
      if (cls) real.push(upgrades[i]);
      else console.printf("\c[YELLOW][BONSAIRC] Class '%s' is not defined or is not a subclass of BaseUpgrade.", upgrades[i]);
    }
    upgrades.move(real);
  }

  static void ExpandWildcard(array<string> real, string wildcard) {
    if (wildcard.IndexOf("*") != wildcard.length()-1) {
      console.printf("\c[YELLOW][BONSAIRC] Malformed wildcard '%s' -- only prefixes ('foo*') are currently supported.", wildcard);
      return;
    }
    string prefix = wildcard.left(wildcard.length()-1).MakeLower();
    uint nrof = 0;
    for (uint i = 0; i < allactorclasses.size(); ++i) {
      let wepcls = (Class<Weapon>)(allactorclasses[i]);
      if (!wepcls) continue;
      string nm = wepcls.GetClassName();
      nm = nm.MakeLower();
      if (nm.IndexOf(prefix) == 0) {
        DEBUG("Add class %s from wildcard %s", nm, wildcard);
        real.push(wepcls.GetClassName());
        ++nrof;
      }
    }
    if (!nrof)
      console.printf("\c[YELLOW][BONSAIRC] Wildcard '%s' did not match any weapon actors.", wildcard);
  }

  static void ValidateWeapons(array<string> weapons) {
    array<string> real;
    for (uint i = 0; i < weapons.size(); ++i) {
      if (weapons[i].IndexOf("*") != -1) {
        ExpandWildcard(real, weapons[i]);
      } else {
        let cls = (Class<Weapon>)(weapons[i]);
        if (cls) real.push(cls.GetClassName());
        else console.printf("\c[YELLOW][BONSAIRC] Class '%s' is not defined or is not a subclass of Weapon", weapons[i]);
      }
    }
    weapons.move(real);
  }

  static void PrintArray(string head, array<string> tail) {
    let buf = "";
    buf.AppendFormat("%s", head);
    for (uint i = 0; i < tail.size(); ++i)
      buf.AppendFormat(" %s", tail[i]);
    console.printf(buf);
  }
}

class ::RC::IfDef : ::RC::Node {
  array<string> classes;
  ::RC rc;

  static ::RC::IfDef Init(array<string> classes, ::RC rc) {
    DEBUG("create instance");
    let node = ::RC::IfDef(new("::RC::IfDef"));
    DEBUG("copy classes");
    node.classes.copy(classes);
    DEBUG("copy rc reference");
    node.rc = rc;
    DEBUG("return instance");
    return node;
  }

  override void Finalize(::EventHandler handler) {
    for (uint i = 0; i < classes.size(); ++i) {
      let cls = (Class<Object>)(classes[i]);
      if (cls) {
        console.printf("\c[CYAN][BONSAIRC] Activating configuration for class %s.", classes[i]);
        rc.Finalize(handler);
        return;
      }
    }
    // None of the classes to watch for were defined? Discard our inner block.
    rc = null;
  }

  override void Configure(::WeaponInfo info) {
    if (!rc) return;
    rc.Configure(info);
  }
}

class ::RC::Register : ::RC::Node {
  array<string> upgrades;

  static ::RC::Register Init(array<string> upgrades) {
    let node = ::RC::Register(new("::RC::Register"));
    node.upgrades.copy(upgrades);
    return node;
  }

  override void Finalize(::EventHandler handler) {
    for (uint i = 0; i < upgrades.size(); ++i) {
      let cls = (Class<::Upgrade::BaseUpgrade>)(upgrades[i]);
      if (cls) {
        console.printf("[BONSAIRC] Registering %s", upgrades[i]);
        handler.UPGRADE_REGISTRY.Register(upgrades[i]);
      }
      else console.printf(
        "\c[YELLOW][BONSAIRC] Class '%s' is not defined or is not a subclass of BaseUpgrade",
        upgrades[i]);
    }
  }

  // No configure -- everything happens on initial load.
}

class ::RC::Unregister : ::RC::Node {
  array<string> upgrades;

  static ::RC::Unregister Init(array<string> upgrades) {
    let node = ::RC::Unregister(new("::RC::Unregister"));
    node.upgrades.copy(upgrades);
    return node;
  }

  override void Finalize(::EventHandler handler) {
    for (uint i = 0; i < upgrades.size(); ++i) {
      let cls = (Class<::Upgrade::BaseUpgrade>)(upgrades[i]);
      if (cls) {
        console.printf("[BONSAIRC] Unregistering %s", upgrades[i]);
        handler.UPGRADE_REGISTRY.Unregister(upgrades[i]);
      }
      else console.printf(
        "\c[YELLOW][BONSAIRC] Class '%s' is not defined or is not a subclass of BaseUpgrade",
        upgrades[i]);
    }
  }

  // No configure -- everything happens on initial load.
}

class ::RC::Merge : ::RC::Node {
  array<string> weapons;

  static ::RC::Merge Init(array<string> weapons) {
    let node = ::RC::Merge(new("::RC::Merge"));
    node.weapons.copy(weapons);
    return node;
  }

  override void Finalize(::EventHandler handler) {
    ValidateWeapons(weapons);
    PrintArray("[BONSAIRC] Merging weapons:", weapons);
  }

  override void Configure(::WeaponInfo info) {
    if (weapons.find(info.wpnClass) == weapons.size()) return;
    // PrintArray("[RC] Installing equivalencies:", weapons);
    info.SetEquivalencies(weapons);
  }
}

class ::RC::Disable : ::RC::Node {
  array<string> weapons;
  array<string> upgrades;

  static ::RC::Disable Init(array<string> weapons, array<string> upgrades) {
    let node = ::RC::Disable(new("::RC::Disable"));
    node.weapons.copy(weapons);
    node.upgrades.copy(upgrades);
    return node;
  }

  override void Finalize(::EventHandler handler) {
    ValidateWeapons(self.weapons);
    ValidateUpgrades(self.upgrades);
    PrintArray("[BONSAIRC] Disabling upgrades:", upgrades);
    PrintArray("           On weapons:", weapons);
  }

  override void Configure(::WeaponInfo info) {
    for (uint i = 0; i < weapons.size(); ++i) {
      if (weapons[i] == info.wpnClass) {
        info.DisableUpgrades(upgrades);
        return;
      }
    }
  }
}

class ::RC::Type : ::RC::Node {
  array<string> weapons;
  ::WeaponType type;

  static ::RC::Type Init(array<string> weapons, ::WeaponType type) {
    let node = ::RC::Type(new("::RC::Type"));
    node.weapons.copy(weapons);
    node.type = type;
    return node;
  }

  override void Finalize(::EventHandler handler) {
    ValidateWeapons(self.weapons);
    PrintArray(
      string.format("[BONSAIRC] Forcing type 0x%02X for:", type),
      weapons);
  }

  override void Configure(::WeaponInfo info) {
    for (uint i = 0; i < weapons.size(); ++i) {
      if (weapons[i] == info.wpnClass) {
        info.typeflags = type;
        return;
      }
    }
  }
}

class ::RCParser : Object play {
  ::RC rc;
  array<::RC> stack;
  array<string> lines; uint line;
  array<string> tokens; uint token;

  ::RC Parse(string lump) {
    self.rc = ::RC(new("::RC"));
    stack.clear(); lines.clear(); tokens.clear();
    lump.split(lines, "\n", true);
    line = 0; token = 0;

    if (!Statements()) return null;
    return rc;
  }

  void push() {
    stack.push(rc);
    rc = ::RC(new("::RC"));
  }
  ::RC pop() {
    DEBUG("pop");
    let tmp = rc;
    rc = stack[stack.size()-1];
    stack.pop();
    DEBUG("done pop");
    return tmp;
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
    console.printf("\c[RED]Error parsing BONSAIRC line %d: expected %s, got %s",
      line+1, expected, ErrorContext());
    return false;
  }
  bool ErrorNoExpectation(string err) {
    console.printf("\c[RED]Error parsing BONSAIRC line %d: %s",
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
    if (peek("ifdef")) { return IfDef(); }
    else if (peek("register")) { return Register(); }
    else if (peek("unregister")) { return Unregister(); }
    else if (peek("merge")) { return Merge(); }
    else if (peek("disable")) { return Disable(); }
    else if (peek("type")) { return Type(); }
    else { return Error("ifdef or directive"); }
  }

  bool IfDef() {
    require("ifdef");
    array<string> classes;
    if (!ClassList(classes, "{")) return false;
    if (classes.size() == 0) return Error("list of classes for ifdef");
    push();
    // read in statements and save them until the "}" is reached, but do not execute
    while (!peek("}")) if (!Statement()) return false;
    let conditioned = pop();
    let ifd = ::RC::IfDef.Init(classes, conditioned);
    rc.push(ifd);
    return require("}");
  }

  bool Register() {
    require("register");
    array<string> upgrades;
    if (!ClassList(upgrades, ";")) return false;
    if (upgrades.size() == 0) return Error("list of upgrades for register");
    rc.push(::RC::Register.Init(upgrades));
    return true;
  }

  bool Unregister() {
    require("unregister");
    array<string> upgrades;
    if (!ClassList(upgrades, ";")) return false;
    if (upgrades.size() == 0) return Error("list of upgrades for unregister");
    rc.push(::RC::Unregister.Init(upgrades));
    return true;
  }

  bool Merge() {
    require("merge");
    array<string> classes;
    if (!PatternList(classes, ";")) return false;
    if (classes.size() == 0) return Error("list of classes or class prefixes for merge");
    rc.push(::RC::Merge.Init(classes));
    return true;
  }

  bool Disable() {
    require("disable");
    array<string> classes; array<string> upgrades;
    if (!PatternList(classes, ":")) return false;
    if (classes.size() == 0) return Error("list of classes or class prefixes for disable");
    if (!ClassList(upgrades, ";")) return false;
    if (upgrades.size() == 0) return Error("list of upgrade classes for disable");
    rc.push(::RC::Disable.Init(classes, upgrades));
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

  bool Type() {
    require("type");
    array<string> classes;
    if (!PatternList(classes, ":")) return false;
    if (classes.size() == 0) return Error("list of classes or class prefixes for type");
    // TODO: allow setting multiple types on the same weapon? E.g. a rifle with underslung
    // grenade launcher might be HITSCAN PROJECTILE.
    ::WeaponType type = 0;
    bool auto_type = false;
    while (!peek(";")) {
      // auto is type 0 and gets special handling.
      if (peek("AUTO")) { auto_type = true; }
      else if (peek("IGNORE")) { type |= ::TYPE_IGNORE; }
      else if (peek("MELEE")) { type |= ::TYPE_MELEE; }
      else if (peek("HITSCAN")) { type |= ::TYPE_HITSCAN; }
      else if (peek("PROJECTILE")) { type |= ::TYPE_PROJECTILE; }
      else if (peek("FASTPROJECTILE")) { type |= ::TYPE_FASTPROJECTILE; }
      else if (peek("SEEKER")) { type |= ::TYPE_SEEKER; }
      else if (peek("RIPPER")) { type |= ::TYPE_RIPPER; }
      else if (peek("BOUNCER")) { type |= ::TYPE_BOUNCER; }
      else return Error("AUTO or IGNORE or weapon type");
      next("");
    }

    if (type && auto_type || type & ::TYPE_IGNORE && type != ::TYPE_IGNORE) {
      return ErrorNoExpectation("can't combine AUTO or IGNORE with other types");
    } else if (!type && !auto_type) {
      return Error("AUTO or IGNORE or one or more weapon types");
    }
    rc.push(::RC::Type.Init(classes, type));
    return require(";");
  }
}

// Lump grammar:
//          rc := statement*
//   statement := comment | ifdef | directive
//     comment := '#' SINGLELINE EOL
//       ifdef := 'ifdef' classes '{' rc '}'
//   directive := register | unregister | merge | disable | type
//    register := 'register' upgrades ';'
//  unregister := 'unregister' upgrades ';'
//       merge := 'merge' classes ';'
//     disable := 'disable' classes ':' upgrades ';'
//        type := 'type' classes ':' typename+ ';'
//    typename := primarytype | secondarytype
// primarytype := 'MELEE' | 'HITSCAN' | 'PROJECTILE' | 'IGNORE' | 'AUTO'
// secondarytype:='FASTPROJECTILE' | 'SEEKER' | 'RIPPER' | 'BOUNCER'
//     classes := (CLASSNAME | classprefix)+
//    upgrades := CLASSNAME+
// classprefix := CLASSNAME '*'

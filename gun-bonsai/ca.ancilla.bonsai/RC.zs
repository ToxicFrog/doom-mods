// Loader for the BONSAIRC lump, including lump parser. See end of file for the
// formal grammar, and the included BONSAIRC for a working example.
#namespace TFLV;
#debug on;

enum ::WeaponType {
  ::TYPE_IGNORE = 0x00,
  ::TYPE_MELEE = 0x01,
  ::TYPE_HITSCAN = 0x02,
  ::TYPE_PROJECTILE = 0x04,
  ::TYPE_AUTO = 0xFF
}

class ::RC : Object play {
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
    for (uint i = 0; i < nodes.size(); ++i) {
      nodes[i].Configure(info);
    }
  }
}

// Individual AST node types.
class ::RC::Node : Object play {
  virtual void Finalize(::EventHandler handler) {
    console.printf("Node: %s", self.GetClassName());
  }

  virtual void Configure(::WeaponInfo info) {
    console.printf("Configure: %s", info.weaponType);
  }

  static void ValidateUpgrades(array<string> upgrades) {
    array<string> real;
    for (uint i = 0; i < upgrades.size(); ++i) {
      let cls = (Class<::Upgrade::BaseUpgrade>)(upgrades[i]);
      if (cls) real.push(upgrades[i]);
      else console.printf("\c[YELLOW]Class '%s' is not defined or is not a subclass of BaseUpgrade", upgrades[i]);
    }
    upgrades.move(real);
  }

  static void ValidateWeapons(array<string> weapons) {
    array<string> real;
    for (uint i = 0; i < weapons.size(); ++i) {
      if (weapons[i].IndexOf("*") != -1) {
        // wildcard handling
        console.printf("\c[YELLOW]Wildcard '%s' is not supported yet", weapons[i]);
      } else {
        let cls = (Class<Weapon>)(weapons[i]);
        if (cls) real.push(weapons[i]);
        else console.printf("\c[YELLOW]Class '%s' is not defined or is not a subclass of Weapon", weapons[i]);
      }
    }
    weapons.move(real);
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
      if (cls) handler.UPGRADE_REGISTRY.Register(upgrades[i]);
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
      if (cls) handler.UPGRADE_REGISTRY.Unregister(upgrades[i]);
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
    ValidateWeapons(self.weapons);
  }

  override void Configure(::WeaponInfo info) {
    super.configure(info);
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
  }

  override void Configure(::WeaponInfo info) {
    super.configure(info);
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
  }

  override void Configure(::WeaponInfo info) {
    super.configure(info);
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
    while (!peek("{")) classes.push(classname()); require("{");
    if (classes.size() == 0) return Error("list of classes for ifdef");
    push();
    // read in statements and save them until the "}" is reached, but do not execute
    while (!peek("}")) if (!Statement()) return false;
    let conditioned = pop();
    DEBUG("init ifdef");
    let ifd = ::RC::IfDef.Init(classes, conditioned);
    DEBUG("done ifdef");
    if (!rc) DEBUG("oh noes");
    rc.push(ifd);
    DEBUG("done push");
    return require("}");
  }

  bool Register() {
    require("register");
    array<string> classes;
    while (!peek(";")) classes.push(classname()); require(";");
    if (classes.size() == 0) return Error("list of classes for register");
    rc.push(::RC::Register.Init(classes));
    return true;
  }

  bool Unregister() {
    require("unregister");
    array<string> classes;
    while (!peek(";")) classes.push(classname()); require(";");
    if (classes.size() == 0) return Error("list of classes for unregister");
    rc.push(::RC::Unregister.Init(classes));
    return true;
  }

  bool Merge() {
    require("merge");
    array<string> classes;
    while (!peek(";")) classes.push(classpattern()); require(";");
    if (classes.size() == 0) return Error("list of classes or class prefixes for merge");
    rc.push(::RC::Merge.Init(classes));
    return true;
  }

  bool Disable() {
    require("disable");
    array<string> classes; array<string> upgrades;
    while (!peek(":")) classes.push(classpattern()); require(":");
    if (classes.size() == 0) return Error("list of classes or class prefixes for disable");
    while (!peek(";")) upgrades.push(classname()); require(";");
    if (upgrades.size() == 0) return Error("list of upgrade classes for disable");
    rc.push(::RC::Disable.Init(classes, upgrades));
    return true;
  }

  bool Type() {
    require("type");
    array<string> classes;
    ::WeaponType type;
    while (!peek(":")) classes.push(classpattern()); require(":");
    if (classes.size() == 0) return Error("list of classes or class prefixes for type");
    // TODO: allow setting multiple types on the same weapon? E.g. a rifle with underslung
    // grenade launcher might be HITSCAN PROJECTILE.
    if (peek("MELEE")) { type = ::TYPE_MELEE; }
    else if (peek("HITSCAN")) { type = ::TYPE_HITSCAN; }
    else if (peek("PROJECTILE")) { type = ::TYPE_PROJECTILE; }
    else if (peek("AUTO")) { type = ::TYPE_AUTO; }
    else if (peek("IGNORE")) { type = ::TYPE_IGNORE; }
    else return Error("weapon type");
    rc.push(::RC::Type.Init(classes, type));
    next("");
    return require(";");
  }

  string classname() { return next("class name"); }
  string classpattern() { return next("class name or prefix"); }
}

// Lump grammar:
//          rc := statement*
//   statement := comment | ifdef | directive
//     comment := "#" SINGLELINE EOL
//       ifdef := "ifdef" classes "{" rc "}"
//   directive := register | unregister | merge | disable | type
//    register := "register" upgrades ";"
//  unregister := "unregister" upgrades ";"
//       merge := "merge" classes ";"
//     disable := "disable" classes ":" upgrades ";"
//        type := "type" classes ":" typename ";"
//    typename := "MELEE" | "HITSCAN" | "PROJECTILE" | "IGNORE" | "AUTO"
//     classes := (CLASSNAME | classprefix)*
//    upgrades := CLASSNAME*
// classprefix := CLASSNAME "*"

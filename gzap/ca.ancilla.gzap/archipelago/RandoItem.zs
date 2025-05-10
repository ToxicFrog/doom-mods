// Information about an item received from Archipelago.
//
// Primarily, this means everything needed to track how many the player has
// received, how many they have left to spawn in, and to do the actual spawning
// if they choose.
//
// It also includes the code that enforces configured inventory limits.

#namespace GZAP;
#debug off;

class ::RandoItem play {
  // Class to instantiate
  string typename;
  // User-facing name
  string tag;
  // Internal category name
  string category;
  // Number vended, must be <= total
  int vended;
  // Number received from randomizer
  int total;

  static ::RandoItem Create(string typename) {
    Class<Actor> itype = typename;
    if (!itype) {
      console.printf("Invalid item type: '%s'", typename);
      return null;
    }
    let item = ::RandoItem(new("::RandoItem"));
    item.typename = typename;
    item.tag = GetDefaultByType(itype).GetTag();
    item.category = ::ScannedItem.ItemCategory(GetDefaultByType(itype));
    item.vended = 0;
    item.total = 0;
    return item;
  }

  void DebugPrint() {
    console.printf("  - %s [category=%s, count=%d/%d, limit=%d]",
      self.typename, self.category, self.vended, self.total, self.GetLimit());
  }

  void SetTotal(int total) {
    if (total == self.total) return;
    self.total = total;
  }

  void Inc() {
    self.total += 1;
  }

  int Remaining() const {
    return self.total - self.vended;
  }

  // Enforce the carry limit on an item. Returns the number of copies vended,
  // which may be 0.
  int EnforceLimit() {
    int limit = GetLimit();
    DEBUG("Enforcing limits on %s: %d left/%d total, limit %d (%s)", self.typename,
        self.Remaining(), self.total, limit, self.category);
    if (limit < 0) return 0;

    int n = 0;
    while (Remaining() > limit) {
      ++n;
      Replicate();
    }
    return n;
  }

  bool, int GetCustomLimit() {
    Array<string> patterns;
    ap_bank_custom.Split(patterns, " ", TOK_SKIPEMPTY);
    foreach (pattern : patterns) {
      Array<string> pair;
      pattern.Split(pair, ":", TOK_SKIPEMPTY);
      if (pair.Size() != 2) {
        console.printf("Skipping incorrectly formatted ap_bank_custom entry: '%s'", pattern);
        continue;
      }

      if (::Util.GlobMatch(pair[0], self.category) || ::Util.GlobMatch(pair[0], self.typename)) {
        return true, pair[1].ToInt();
      }
    }
    return false, 0;
  }

  int GetLimit() {
    if (::PlayEventHandler.Get().IsPretuning()) return 0;

    let [custom, limit] = GetCustomLimit();
    if (custom) return limit;

    if (self.category == "weapon") {
      return ap_bank_weapons;
    } else if (self.category.IndexOf("-ammo") > -1) {
      return ap_bank_ammo;
    } else if (self.category.IndexOf("-armor") > -1) {
      return ap_bank_armour;
    } else if (self.category.IndexOf("-health") > -1) {
      return ap_bank_health;
    } else if (self.category == "powerup") {
      return ap_bank_powerups;
    } else{
      return ap_bank_other;
    }
  }

  // Thank you for choosing Value-Rep™!
  void Replicate() {
    DEBUG("Replicating %s", self.typename);
    if (self.vended >= self.total) return;
    self.vended++;
    ::PerLevelHandler.Get().AllowDropsBriefly(2);
    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      if (!players[p].mo) continue;

      let thing = players[p].mo.Spawn(self.typename, players[p].mo.pos, ALLOW_REPLACE);
      thing.ClearCounters();
    }
  }

  // Used for sorting. Returns true if this item should be sorted before the
  // other item. At present we sort exclusively by name, disregarding count;
  // the menu code will skip over 0-count items.
  bool Order(::RandoItem other) {
    return self.tag < other.tag;
  }
}

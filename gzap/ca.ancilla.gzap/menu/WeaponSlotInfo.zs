// Handling for weapon slot data -- mapping AP weapons to (slot,index) info,
// and then generating parts of the AP UI from that.
//
// For associating weapons with slots, our approach is:
// - if the weapon is known to players[0].weapon, use that info
// - if not, check the info in the various uzdoom built in PlayerPawn types:
//   {Doom,Heretic,Chex,Strife,Fighter,Cleric,Mage}Player
// - if none of those work, assign the weapon to a slot based on the capitalized
//   first letter of its typename.

#namespace GZAP;
#debug off;

class ::SingleSlotInfo {
  string slot;
  int total;
  // Which weapons are in this slot, in index order
  Array<string> weapon_types;
  // How many we have found in each scope
  Map<string, ::StringSet> held;

  static ::SingleSlotInfo Create() {
    return ::SingleSlotInfo(new("::SingleSlotInfo"));
  }

  void InsertAtIndex(string typename, int index) {
    // Find the first free slot >= index, which may be off the end of the array.
    while (index < self.weapon_types.Size() && self.weapon_types[index]) {
      ++index;
    }
    self.weapon_types.Insert(index, typename);
  }

  void MarkHeld(string scope, string typename) {
    if (!self.held.CheckKey(scope)) {
      self.held.Insert(scope, ::StringSet.Create());
    }
    self.held.Get(scope).Insert(typename);
  }

  bool IsHeld(string scope, string typename) {
    return self.held.CheckKey(scope) && self.held.Get(scope).Contains(typename);
  }
}

// Information about what weapon grants the player has.
class ::WeaponSlotInfo {
  ::RandoState apstate;
  Map<string, ::SingleSlotInfo> slots;

  static ::WeaponSlotInfo Create(::RandoState apstate) {
    let this = ::WeaponSlotInfo(new("::WeaponSlotInfo"));
    this.apstate = apstate;
    this.BuildSlotInfo();
    return this;
  }

  int,int GetSlotFromPawn(string playertype, string weptype) {
    Class<PlayerPawn> cls = playertype;
    let pawn = PlayerPawn(GetDefaultByType(cls));

    // Each entry in Slot is a space-separated list of weapon typenames.
    for (int i = 0; i < 10; ++i) {
      string slotlist = pawn.Slot[i];
      if (slotlist.IndexOf(weptype) == -1) continue;
      Array<string> types;
      slotlist.Split(types, " ", TOK_SKIPEMPTY);
      for (int j = 0; j < types.Size(); ++j) {
        if (types[j] == weptype) return i,j;
      }
    }

    return -1,-1;
  }

  string,int GetSlotForWeapon(string typename) {
    Class<Weapon> cls = typename;
    if (!cls) return typename.MakeUpper().Left(1),0;

    // If the player is not using a weapon replacer mod, or if they are using
    // one that adds to the canonical slots rather than replacing them, we can
    // just query the player's slot data.
    bool assigned = false;
    int slotnum, indexnum;
    [assigned, slotnum, indexnum] = players[0].weapons.LocateWeapon(cls);
    if (assigned) return string.format("%d", slotnum),indexnum;

    // Can't find it there. Optimistically assume that they are playing a
    // vanilla-compatible wad and check the vanilla slot assignments built into
    // the engine.
    [slotnum, indexnum] = GetSlotFromPawn("DoomPlayer", typename);
    if (slotnum >= 0) return string.format("%d", slotnum),indexnum;
    [slotnum, indexnum] = GetSlotFromPawn("HereticPlayer", typename);
    if (slotnum >= 0) return string.format("%d", slotnum),indexnum;
    [slotnum, indexnum] = GetSlotFromPawn("StrifePlayer", typename);
    if (slotnum >= 0) return string.format("%d", slotnum),indexnum;
    [slotnum, indexnum] = GetSlotFromPawn("ChexPlayer", typename);
    if (slotnum >= 0) return string.format("%d", slotnum),indexnum;
    [slotnum, indexnum] = GetSlotFromPawn("FighterPlayer", typename);
    if (slotnum >= 0) return string.format("%d", slotnum),indexnum;
    [slotnum, indexnum] = GetSlotFromPawn("ClericPlayer", typename);
    if (slotnum >= 0) return string.format("%d", slotnum),indexnum;
    [slotnum, indexnum] = GetSlotFromPawn("MagePlayer", typename);
    if (slotnum >= 0) return string.format("%d", slotnum),indexnum;

    // Nope! This means they're playing a wad with custom weapons and slot
    // assignments, but have paired it with a mod that overwrites those
    // assignments.
    return typename.MakeUpper().Left(1), 0;
  }

  void BuildSlotInfo() {
    Map<string, string> weapons_to_slot;

    foreach (item : self.apstate.items) {
      if (!item.IsWeaponGrant()) continue;
      let [scope,typename] = item.WeaponGrantInfo();
      let held = item.total > 0;

      if (!weapons_to_slot.CheckKey(typename)) {
        // First time we've seen this weapon type, figure out which slot it belongs to.
        let [slot,index] = GetSlotForWeapon(typename);

        if (!self.slots.CheckKey(slot)) {
          self.slots.Insert(slot, ::SingleSlotInfo.Create());
        }
        self.slots.Get(slot).InsertAtIndex(typename, index);
        weapons_to_slot.Insert(typename, slot);
      }

      if (held) {
        let slot = weapons_to_slot.Get(typename);
        let info = self.slots.Get(slot);
        info.MarkHeld(scope, typename);
      }
    }

    return;
  }

  void UpdateScope(string scope) {
    foreach (slot, info : self.slots) {
      foreach (weapon : info.weapon_types) {
        string grant_type = scope == "*" ? "::WeaponGrant_"..weapon : "::WeaponGrant_"..weapon.."_"..scope;
        let held = self.apstate.CountItem(grant_type) > 0;
        if (held) info.MarkHeld(scope, weapon);
      }
    }
  }

  string MakeWeaponList(string scope, string head_format, string rest_format) {
    string SLOT_ORDER = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    let buf = "";
    string last_slot = "";

    for (int idx = 0; idx < SLOT_ORDER.Length(); ++idx) {
      let slot = SLOT_ORDER.Mid(idx, 1);
      let info = self.slots.GetIfExists(slot);
      if (!info) continue;

      foreach (weapon : info.weapon_types) {
        // Slot population may leave gaps in the weapon_types.
        if (!weapon) continue;
        Class<Weapon> cls = weapon;
        readonly<Weapon> thing = GetDefaultByType(cls);
        let tag = ::RC.Get().GetTag(thing);
        let held = info.IsHeld(scope, weapon);
        if (last_slot != slot) {
          buf.AppendFormat(head_format, held ? "FIRE" : "DARKGRAY", slot, tag);
          last_slot = slot;
        } else {
          buf.AppendFormat(rest_format, held ? "FIRE" : "DARKGRAY", tag);
        }
      }
    }

    return buf;
  }

  string ShortWeaponList(string scope) {
    return MakeWeaponList(scope, "\c[%s]%s", "\c[%s]+");
  }

  string LongWeaponList(string scope) {
    return MakeWeaponList(scope, "\n\c[%s]  [%s] %s", "\n\c[%s]   +  %s");
  }
}


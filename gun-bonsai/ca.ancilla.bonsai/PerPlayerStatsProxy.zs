// This sits in the player's inventory and does two things:
// - holds the PerPlayerStats where all the really interesting stuff lives
// - implements the ModifyDamage and HandlePickup handlers
// On game startup, the StaticEventHandler creates one of these and stuffs it
// into the player, if they don't already have done.
// If they do have one, its contents override the one in the StaticEventHandler,
// if different, so that loading a save file works as expected.
// In normal play, the PerPlayerStats held by this are also referenced by the
// StaticEventHandler and most lookups go through that.
#namespace TFLV;

class ::PerPlayerStatsProxy : Inventory {
  ::PerPlayerStats stats;

  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +INVENTORY.IGNORESKILL;
    +INVENTORY.UNTOSSABLE;
    +INVENTORY.UNDROPPABLE;
    +INVENTORY.QUIET;
  }

  States {
    Spawn:
      TNT1 A -1;
      STOP;
    Poll:
      TNT1 A 1 {
        DEBUG("PPSP poll");
        stats.TickStats();
      }
      LOOP;
  }

  void Initialize(::PerPlayerStats stats) {
    self.stats = stats;
    self.stats.Initialize(owner);
    self.SetStateLabel("Poll");
  }

  override void ModifyDamage(
      int damage, Name damageType, out int newdamage, bool passive,
      Actor inflictor, Actor source, int flags) {
    stats.ModifyDamage(damage, damageType, newdamage, passive, inflictor, source, flags);
  }

  // Special pickup handling so that if the player picks up an LD legendary weapon
  // that upgrades their mundane weapon in-place, we handle this correctly rather
  // than thinking it's a mundane weapon that earned an LD effect through leveling
  // up.
  override bool HandlePickup(Inventory item) {
    if (Weapon(item)) {
      // Flag the weaponinfo for a full rebuild on the next tick.
      // We don't do it immediately because the purpose of this is to transfer
      // weaponinfo from old weapons to new weapons that replace them, and in some
      // mods the new weapon is added before the old one is removed.
      // This is only really relevant when using BIND_WEAPON and it's important
      // that we rebind the info to the replacement before it gets cleaned up.
      stats.weaponinfo_dirty = true;
      return super.HandlePickup(item);
    }

    // TODO: peel most of this into a separate mod.
    // Workaround for zscript `is` operator being weird.
    string LDWeaponNameAlternationType = "LDWeaponNameAlternation";
    string LDPermanentInventoryType = "LDPermanentInventory";
    if (item is LDWeaponNameAlternationType) return super.HandlePickup(item);
    if (!(item is LDPermanentInventoryType)) return super.HandlePickup(item);

    string cls = item.GetClassName();
    if (cls.IndexOf("EffectActive") < 0) return super.HandlePickup(item);

    // If this is flagged as "notelefrag", it means it was produced by the level-
    // up code and should upgrade our current item in place rather than invalidating
    // its info block.
    if (item.bNOTELEFRAG) return super.HandlePickup(item);

    // At this point we know that the pickup is a Legendoom weapon effect token
    // and it's not one we created. So we need to figure out if the player has
    // an existing entry for a mundane weapon of the same type and clear it if so.
    // TODO: this may need a redesign in light of the new rebinding code.
    cls = cls.Left(cls.IndexOf("EffectActive"));
    for (int i = 0; i < stats.weapons.size(); ++i) {
      if (stats.weapons[i].wpn is cls) {
        stats.weapons[i].wpn = null;
      }
    }
    return super.HandlePickup(item);
  }
}

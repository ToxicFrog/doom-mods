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
#debug on;

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
      TNT1 A 1 { stats.TickStats(); }
      LOOP;
  }

  void Initialize(::PerPlayerStats stats) {
    self.stats = stats;
    self.stats.Initialize(self);
    self.SetStateLabel("Poll");
  }

  Actor LookingAt() {
    FTranslatedLineTarget target;
    owner.AimLineAttack(owner.angle, 256, target, 0,
      ALF_CHECKNONSHOOTABLE|ALF_FORCENOSMART|128);
    return target.linetarget;
  }

  override void Tick() {
    let pawn = PlayerPawn(owner);
    if (!pawn) return;

    self.stats.TickStats();

    if (pawn.player.buttons & BT_USE) {
      let seen = LookingAt();
      DEBUG("AimTarget: %s", TAG(seen));
      if (seen is "LDWeaponPickup") {
        PickupLDWeapon(Inventory(seen));
      }
    }
  }

  void PickupLDWeapon(Inventory item) {
    // First, install a cooldown so it doesn't pop up the info screen, then try
    // picking it up normally.
    owner.GiveInventoryType("LDWeaponDisplayCooldown");
    if (item.CallTryPickup(owner)) {
      // If that worked, great, we're done.
      DEBUG("Successfully picked up %s", TAG(item));
      return;
    }
    owner.TakeInventory("LDWeaponDisplayCooldown", 999);

    // Otherwise, try to extract the powerup from it.
    string cls = item.GetClassName();
    string prefix = cls.Left(cls.IndexOf("Pickup"));
    Inventory effect = ::LegendoomUtil.FindItemWithPrefix(item, prefix.."Effect_");
    if (effect) {
      PickupEffect(effect.GetClassName());
    }
    // FIXME: also extract the rarity and associate it with the effect
    // we probably need to replace the effect list with structs rather than strings,
    // so it can store effect name + rarity level + maybe other stuff in the future
    item.Destroy();
    // some sort of fancy visual effect here?
  }

  void PickupEffect(string effect) {
    int idx = effect.IndexOf("Effect_");
    string prefix = effect.Left(idx);
    Weapon wpn = Weapon(owner.FindInventory(prefix));
    DEBUG("PickupEffect(%s): prefix=%s weapon=%s", effect, prefix, TAG(wpn));
    if (!wpn) return;
    let info = stats.GetOrCreateInfoFor(wpn);
    if (!info) return;
    info.AddEffect(effect);
  }

  // Special pickup handling so that if the player picks up an LD legendary weapon
  // that upgrades their mundane weapon in-place, we handle this correctly rather
  // than thinking it's a mundane weapon that earned an LD effect through leveling
  // up.
  override bool HandlePickup(Inventory item) {
    // DEBUG("HandlePickup: %s", item.GetClassName());
    if (Weapon(item)) {
      // Flag the weaponinfo for a full rebuild on the next tick.
      // We don't do it immediately because the purpose of this is to transfer
      // weaponinfo from old weapons to new weapons that replace them, and in some
      // mods the new weapon is added before the old one is removed.
      // This is only really relevant when using BIND_WEAPON and it's important
      // that we rebind the info to the replacement before it gets cleaned up.
      DEBUG("Marking weaponinfo dirty");
      stats.weaponinfo_dirty = true;
    }
    if (item is "LDPermanentInventory") HandleLegendoomPickup(item);
    return super.HandlePickup(item);
  }

  // Picking up a new weapon looks like picking up LDWeaponTypeLegendaryCommon
  // and then immediately after that, picking up LDWeaponTypeEffect_EffectName
  // So when we pick up the weapon we should create and bind upgrade handlers
  // for it, and then we install the effect in it.
  void HandleLegendoomPickup(Inventory item) {
    if (item is "LDWeaponNameAlternation") return;

    string cls = item.GetClassName();

    int idx = cls.IndexOf("Effect_");
    if (idx >= 0) {
      // Picked up a new effect.
      HandleLDEffectPickup(item, cls.Left(idx));
    }

    idx = cls.IndexOf("Legendary");
    if (idx >= 0) {
      // Picked up a rarity marker.
      HandleLDRarityPickup(item, cls.Left(idx));
    }
  }

  void HandleLDEffectPickup(Inventory item, string prefix) {
    Weapon wpn = Weapon(owner.FindInventory(prefix));
    DEBUG("LDPickup(%s): prefix=%s weapon=%s", TAG(item), prefix, TAG(wpn));
    if (!wpn) return;
    let info = stats.GetOrCreateInfoFor(wpn);
    if (!info) return;
    info.AddEffect(item.GetClassName());
  }

  void HandleLDRarityPickup(Inventory item, string prefix) {
    Weapon wpn = Weapon(owner.FindInventory(prefix));
    DEBUG("LDPickup(%s): prefix=%s weapon=%s", TAG(item), prefix, TAG(wpn));
    if (!wpn) return;
    let info = stats.GetOrCreateInfoFor(wpn);
    if (!info) return;
    // FIXME: set rarity for weapon
  }

    // if (cls.IndexOf("EffectActive") < 0) return false;

    // // If this is flagged as "notelefrag", it means it was produced by the level-
    // // up code and should upgrade our current item in place rather than invalidating
    // // its info block.
    // if (item.bNOTELEFRAG) return;

    // // At this point we know that the pickup is a Legendoom weapon effect token
    // // and it's not one we created. So we need to figure out if the player has
    // // an existing entry for a mundane weapon of the same type and clear it if so.
    // // TODO: this may need a redesign in light of the new rebinding code.
    // cls = cls.Left(cls.IndexOf("EffectActive"));
    // for (int i = 0; i < stats.weapons.size(); ++i) {
    //   if (stats.weapons[i].wpn is cls) {
    //     stats.weapons[i].wpn = null;
    //   }
    // }
  // }
}

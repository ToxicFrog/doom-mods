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
#debug off;

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
    owner.AimLineAttack(owner.angle, 128, target, 0,
      ALF_CHECKNONSHOOTABLE|ALF_FORCENOSMART|128);
    return target.linetarget;
  }

  override void Tick() {
    let pawn = PlayerPawn(owner);
    if (!pawn) return;

    self.stats.TickStats();

    if (pawn.player.buttons & BT_USE) {
      let seen = LookingAt();
      if (seen is "LDWeaponPickup") {
        PickupLDWeapon(Inventory(seen));
      }
    }
  }

  // TODO a bunch of pickup handler code in here should probably be moved into
  // the PerPlayerStats and out of the proxy

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
    DEBUG("PickupLDWeapon(%s)", TAG(item));
    string cls = item.GetClassName();
    string prefix = cls.Left(cls.IndexOf("Pickup"));
    Inventory effect = ::LegendoomUtil.FindItemWithPrefix(item, prefix.."Effect_");
    if (effect) {
      uint r,g,b;
      [r,g,b] = ::LegendoomUtil.GetRarityColour(PickupEffect(item, prefix));
      item.ACS_ScriptCall("Draw_Pentagram", item.radius, r, g, b);
      item.Destroy();
    } else {
      item.ACS_ScriptCall("Draw_Pentagram", item.radius, 0, 0, 0);
    }
  }

  ::LDRarity PickupEffect(Actor item, string prefix) {
    Weapon wpn = Weapon(owner.FindInventory(prefix));
    if (!wpn) return RARITY_MUNDANE;
    let info = stats.GetOrCreateInfoFor(wpn);
    if (!info) return RARITY_MUNDANE;
    return info.AddEffectFromActor(item);
  }

  // Special pickup handling so that if the player picks up an LD legendary weapon
  // that upgrades their mundane weapon in-place, we handle this correctly rather
  // than thinking it's a mundane weapon that earned an LD effect through leveling
  // up.
  override bool HandlePickup(Inventory item) {
    // if (item is "LDWeaponNameAlternation") return super.HandlePickup(item);
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

    DEBUG("HandleLegendoomPickup(%s)", TAG(item));
    string cls = item.GetClassName();

    int idx = cls.IndexOf("EffectActive");
    if (idx >= 0) {
      // Picked up a new effect.
      HandleLDEffectPickup(cls.Left(idx));
    }
  }

  // Note that this depends on picking up the rarity token before the effect
  // token! If the order gets reversed this will crash.
  void HandleLDEffectPickup(string prefix) {
    DEBUG("HandleLDEffectPickup: %s", prefix);
    Weapon wpn = Weapon(owner.FindInventory(prefix));
    if (!wpn) return;
    let info = stats.GetOrCreateInfoFor(wpn);
    if (!info) return;
    info.AddEffectFromActor(owner);
  }
}

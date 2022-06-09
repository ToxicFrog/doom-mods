class TFLV_LegendoomCompat : Inventory {
  TFLV_PerPlayerStats stats;
  TFLV_WeaponInfo wielded;

  Default {
    +Inventory.IgnoreSkill;
    +Inventory.Untossable;
  }

  override bool HandlePickup(Inventory item) {
    // Does not stack, ever.
    return false;
  }

  void Debug() {
    // let stats = owner.
    // let wielded = owner.player.ReadyWeapon;
    if (!wielded || !(wielded.weapon is "LDWeapon")) {
      console.printf("%s isn't an LDWeapon and can't receive Legendoom upgrades!", wielded.weapon.GetTag());
      return;
    }
    // It works!
    // Of course, if you already have an LD ability it just gives you another
    // one, and things get increasingly weird the further you go.
    string cls = wielded.weapon.GetClassName().."RandomLegendary";
    owner.GiveInventoryType(cls);
    console.printf("Gave the player a %s", cls);
  }

  // We use States here and not just a simple method because we need to be able
  // to insert delays to let LD item generation code do its things at various
  // times.
  States {
    LDLevelUp:
      TNT1 A 1 { invoker.Debug(); }
      STOP;
  }
}

#namespace TFLV::Upgrade;
#debug off;

class ::Swiftness : ::BaseUpgrade {
  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    let aux = ::Swiftness::Aux(player.Spawn("::Swiftness::Aux"));
    aux.EffectTics = GetCap(level, 1);
    aux.strength = level;
    GiveItem(player, aux);
  }

  static uint GetCap(uint level, uint stacks=1) {
    return 28 + 7*level + 5*(stacks-1);
  }

  void GiveItem(PlayerPawn player, Inventory item) {
    item.ClearCounters();
    if (!item.CallTryPickup(player)) item.Destroy();
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsMelee() || info.IsWimpy();
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("duration", string.format("%.1fs", GetCap(level, 1)/35.0));
    fields.insert("combo-bonus", string.format("%.2fs", 5.0/35.0));
  }
}

class ::Swiftness::Aux : PowerupGiver {
  Default {
    +Inventory.AUTOACTIVATE;
    // +Inventory.ADDITIVETIME;
    +Inventory.NOSCREENBLINK;
    +Inventory.ALWAYSPICKUP;
    Powerup.Type "::Swiftness::Power";
    // Powerup.Type "PowerTimeFreezer";
    Powerup.Duration 999;
    Inventory.Amount 1;
    Inventory.MaxAmount 0;
  }
}

// We have a complication here, in that PowerTimeFreezer is designed to gradually
// return the world to normal speed in the last 128t (3.7s) of its effect.
// that means that durations less than that won't actually stop time, just slow
// it down.
// We work around this by:
// (a) adding 128t to the duration, so that time stops immediately
// (b) once the time remaining drops below (128+32), setting it to 48, giving us
//     a 75% slowdown, and then
// (c) once it drops below 32, cancelling the effect.
// This gives us a ramp from full time stop to normal speed in half a second.
class ::Swiftness::Power : PowerTimeFreezer {
  override void InitEffect() {
    EffectTics = 128 + ::Swiftness.GetCap(strength, amount);
    DEBUG("Initialized with cap=%d actual=%d", ::Swiftness.GetCap(strength, amount), EffectTics);
    super.InitEffect();
    S_ResumeSound(false); // unpause music and SFX
  }

  override void DoEffect() {
    super.DoEffect();
    if (EffectTics <= 32) EffectTics = 1;
    else if (EffectTics <= 128 && EffectTics > 64) EffectTics = 48;
  }

  override bool CanPickup(Actor other) { return true; }
  override bool IsBlinking() { return false; }

  override bool HandlePickup(Inventory item) {
    if (item.GetClass() != GetClass()) return super.HandlePickup(item);
    self.amount++;
    let cap = ::Swiftness.GetCap(strength, amount);
    EffectTics = 128 + cap;
    DEBUG("Now %d stacks, reset tics to %d/%d tics", amount, cap, EffectTics);
    item.bPICKUPGOOD = true;
    return true;
  }
}

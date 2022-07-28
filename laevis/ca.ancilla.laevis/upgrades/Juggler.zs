#namespace TFLV::Upgrade;
#debug off;

class ::Juggler : ::BaseUpgrade {
  bool InState(Actor wpn, StateLabel state) {
    return wpn.InStateSequence(wpn.CurState, wpn.ResolveState(state));
  }

  override void Tick(Actor owner) {
    let wpn = owner.player.ReadyWeapon;
    if (!wpn) return;
    // Ideally we should just check if the weapon's current state in inside the
    // state returned by GetDownState() or GetUpState(). However, for some reason,
    // this doesn't work. So instead we have this really hacky way of inferring
    // if the weapon is being raised or lowered.
    let psp = owner.player.GetPSprite(PSP_WEAPON);
    if (psp.y == WEAPONTOP) return; // Weapon sprite is in position, so no switch is occurring.
    if (owner.player.PendingWeapon != WP_NOCHANGE) {
      // We are currently lowering our weapon, and WP_NOCHANGE points to the new one.
      psp.y = WEAPONBOTTOM;
    } else {
      // We are raising our weapon.
      psp.y = WEAPONTOP;
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return stats.upgrades.Level("::Juggler") == 0;
  }
}


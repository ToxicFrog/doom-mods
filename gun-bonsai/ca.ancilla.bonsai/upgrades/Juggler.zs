#namespace TFLV::Upgrade;
#debug off;

class ::Juggler : ::BaseUpgrade {
  bool InState(PSprite psp, State state) {
    if (!psp.CurState || !state) return false;
    return psp.CurState.InStateSequence(state);
    // return wpn.InStateSequence(wpn.CurState, wpn.ResolveState(state));
  }

  override void Tick(Actor owner) {
    let wpn = owner.player.ReadyWeapon;
    let psp = owner.player.GetPSprite(PSP_WEAPON);
    if (!wpn || !psp) return;

    if (InState(psp, wpn.GetDownState())) {
      psp.y = WEAPONBOTTOM;
    } else if (InState(psp, wpn.GetUpState())) {
      psp.y = WEAPONTOP;
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return stats.upgrades.Level("::Juggler") == 0;
  }
}


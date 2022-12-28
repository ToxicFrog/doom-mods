#namespace TFLV::Upgrade;
#debug off;

class ::RapidFire : ::BaseUpgrade {
  void SpeedUp(PSprite psp, uint n) {
    DEBUG("rapidfire: state %p, tics %d - %d", psp.CurState, psp.tics, n);
    for (uint i = 0; i < n; ++i) {
      if (psp.tics) {
        psp.tics--;
        while (psp.tics == 0) {
          psp.SetState(psp.CurState.NextState, true);
          DEBUG("rapidfire: advance state to %p tics = %d to remove = %d", psp.CurState, psp.tics, n - i);
        }
      }
    }
  }

  override void Tick(Actor owner) {
    let psp = owner.player.GetPSprite(PSP_WEAPON);
    if (psp.tics != -1) {
      // Speed up by 1 tic for every 2 levels of the upgrade; on odd-numbered levels,
      // speed up by an extra tic on odd-numbered gametics.
      SpeedUp(psp, level/2 + (level % 2) * (gametic % 2));
    } else {
      DEBUG("Skipping rapidfire, process=%d tics=%d", psp.processPending, psp.tics);
    }
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::RapidFire") < 10
      && (info.wpn.AmmoType1 || info.wpn.AmmoType2);
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("speedup", string.format("x%.1f", 1 + level/2.0));
  }
}

// Kept around for compatibility with older saves.
class ::RapidFire::Power : PowerDoubleFiringSpeed {
  Default { Powerup.Duration 1; }
}

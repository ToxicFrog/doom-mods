#namespace TFLV::Upgrade;
#debug off;

class ::RapidFire : ::BaseUpgrade {
  void SpeedUp(PSprite psp, uint n) {
    DEBUG("reduce tic for psp by %d", n);
    for (uint i = 0; i < n; ++i) {
      if (psp.tics) {
        psp.tics--;
        while (psp.tics == 0) psp.SetState(psp.CurState.NextState);
      }
    }
  }

  override void Tick(Actor owner) {
    let psp = owner.player.GetPSprite(PSP_WEAPON);
    if (psp.processPending && psp.tics != -1) {
      // Speed up by 1 tic for every 2 levels of the upgrade; on odd-numbered levels,
      // speed up by an extra tic on odd-numbered gametics.
      SpeedUp(psp, level/2 + (level % 2) * (gametic % 2));
    }
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::RapidFire") < 10
      && (info.wpn.AmmoType1 || info.wpn.AmmoType2);
  }

  override void GetTooltipFields(Array <string> fields, uint level) {
    fields.push(string.format("x%.1f", 1 + level/2));
  }
}

// Kept around for compatibility with older saves.
class ::RapidFire::Power : PowerDoubleFiringSpeed {
  Default { Powerup.Duration 1; }
}

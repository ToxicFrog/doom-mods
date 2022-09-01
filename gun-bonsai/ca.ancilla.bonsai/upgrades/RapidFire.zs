#namespace TFLV::Upgrade;
#debug off;

class ::RapidFire : ::BaseUpgrade {
  override void OnActivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    super.OnActivate(stats, info);
    stats.owner.GiveInventoryType("::RapidFire::Power");
  }

  override void OnDeactivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    super.OnDeactivate(stats, info);
    stats.owner.TakeInventory("::RapidFire::Power", 255);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::RapidFire") < 1;
  }
}

class ::RapidFire::Power : PowerDoubleFiringSpeed {
  Default { Powerup.Duration 0x7FFFFFFF; }
}

/*
// this runs inside the PSprite
        void Tick()
        {
                if (processPending)
                {
                        // drop tic count and possibly change state
                        if (Tics != -1) // a -1 tic count never changes
                        {
                                Tics--;
                                // [BC] Apply double firing speed.
                                if (bPowDouble && Tics && (Owner.mo.FindInventory ("PowerDoubleFiringSpeed", true))) Tics--;
                                if (!Tics && Caller != null) SetState(CurState.NextState);
                        }
                }
        }
*/
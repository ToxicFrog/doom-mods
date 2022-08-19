#namespace TFLV::Upgrade;

class ::HomingShots : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.bSEEKERMISSILE = true;
    let aux = ::HomingShots::Aux(shot.GiveInventoryType("TFLV_Upgrade_HomingShots_Aux"));
    aux.level = level;
    aux.SetStateLabel("Homing");
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsSlowProjectile() && info.upgrades.Level("::HomingShots") < 4;
  }
}

class ::HomingShots::Aux : Inventory {
  uint level;

  States {
    Homing:
      TNT1 A 5 DoHoming();
      LOOP;
  }

  void DoHoming() {
    if (!owner) {
      // Our owning projectile vanished. Ideally this should have destroyed us
      // as well, but sometimes that doesn't happen.
      Destroy();
      return;
    }
    owner.A_SeekerMissile(
      level, // terminal homing cone radius
      level+2, // max turn angle per tic, degrees
      SMF_LOOK | SMF_PRECISE | SMF_CURSPEED,
      256, // chance of acquiring a new target if it doesn't have one
      min(level, 10)); // scan range for new targets in blocks
  }
}

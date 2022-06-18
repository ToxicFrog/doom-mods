#namespace TFLV::Upgrade;

class ::HomingShots : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    let aux = ::HomingShots::Aux(shot.GiveInventoryType("TFLV_Upgrade_HomingShots_Aux"));
    aux.level = level;
    aux.SetStateLabel("Homing");
  }
}

class ::HomingShots::Aux : TFLV::Force {
  uint level;

  States {
    Homing:
      TNT1 A 5 DoHoming();
      LOOP;
  }

  void DoHoming() {
    owner.A_SeekerMissile(
      level, // terminal homing cone radius
      level+2, // max turn angle per tic, degrees
      SMF_LOOK | SMF_PRECISE | SMF_CURSPEED,
      256, // chance of acquiring a new target if it doesn't have one
      min(level, 10)); // scan range for new targets in blocks
  }
}
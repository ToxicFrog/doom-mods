#namespace TFLV::Upgrade;
#debug off;

class ::DecoyFlares : ::BaseUpgrade {
  // Range within which we distract enemy shots.
  uint FlareRange(uint level) {
    return 96 + level*32; // 4m + 1m/level
  }

  override void OnProjectileCreated(Actor player, Actor new_shot) {
    // Find nearby seekers and redirect them at this projectile.
    let radius = FlareRange(self.level);
    ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
    Actor shot;
    while (shot = Actor(it.next())) {
      if (!shot || !shot.bSEEKERMISSILE || shot.tracer != player || player.Distance3D(shot) > radius) {
        continue;
      }
      shot.tracer = new_shot;
      shot.target = player;
    }
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsSlowProjectile();
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("flare-range", AsMeters(FlareRange(level)));
  }
}

class TFLV_Upgrade_ProjectileSpeed : TFLV_BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.A_ScaleVelocity(1 + 0.5*level);
  }
}

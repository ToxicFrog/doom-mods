#namespace TFLV::Upgrade;

class ::ProjectileSpeed : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.A_ScaleVelocity(1 + 0.5*level);
  }
}

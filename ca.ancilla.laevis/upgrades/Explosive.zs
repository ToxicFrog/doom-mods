#namespace TFLV::Upgrade;

class ::ExplosiveShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    bool ok;
    Actor act;
    [ok, act] = shot.A_SpawnItemEx(
      "::ExplosiveShots::Boom",
      0, 0, 0, 0, 0, 0, 0,
      SXF_TRANSFERPOINTERS);
    let boom = ::ExplosiveShots::Boom(act);
    console.printf("Spawning Boom, damage=%d", damage/2);
    boom.damage = damage/2;
    boom.radius = 200 + 50 * level;
  }
}

class ::ExplosiveShots::Boom : Actor {
  uint damage;
  uint radius;

  Default {
    // +PROJECTILE; can't set this in zscript?
    +NOBLOCKMAP;
    +NOGRAVITY;
    +MISSILE;
  }

  States {
    Spawn:
      TNT1 A 1;
      LFBX A 7 A_Explode(damage, radius);
      LFBX BC 7;
      STOP;
  }
}

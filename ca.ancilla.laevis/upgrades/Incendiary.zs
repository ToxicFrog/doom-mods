#namespace TFLV::Upgrade;

class ::IncendiaryShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    shot.A_SpawnItemEx(
      "::IncendiaryFire",
      0, 0, 20, // offset
      0, 0, 0, // v
      0.0, // theta
      SXF_TRANSFERPOINTERS);
  }
}

class ::IncendiaryFire : Actor {
  Default {
    ReactionTime 120;
    DamageType "Fire";
    +NOBLOCKMAP;
    +NOGRAVITY;
    +NOTELEPORT;
    +NODAMAGETHRUST;
    +DONTSPLASH;
    RenderStyle "Add";
  }
  States {
    Spawn:
      FIRE A 2 Bright A_Explode(2, 30);
      FIRE BCB 2 Bright A_Countdown();
      LOOP;
    Death:
      FIRE CDEFGH 2 Bright;
      STOP;
  }
}


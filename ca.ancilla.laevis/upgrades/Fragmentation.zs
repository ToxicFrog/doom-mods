#namespace TFLV::Upgrade;
#debug on

class ::FragmentationShots : ::BaseUpgrade {
  override ::UpgradePriority Priority() { return ::PRI_FRAGMENTATION; }

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    bool ok;
    Actor act;
    // TODO: new Upgrade-specific Spawn function that sets special1
    // and target appropriately.
    let boom = ::FragmentationShots::Boom(shot.Spawn("::FragmentationShots::Boom", shot.pos));
    boom.special1 = Priority();
    boom.target = pawn;
    boom.damage = ceil(damage * 0.2);
    boom.fragments = 8 + level*8;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsProjectileWeapon() && !info.weapon.bMELEEWEAPON;
  }
}

class ::FragmentationShots::Boom : Actor {
  uint level;
  uint damage;
  uint fragments;

  Default {
    // +PROJECTILE; can't set this in zscript?
    +NOBLOCKMAP;
    +NOGRAVITY;
    +MISSILE;
    +NODAMAGETHRUST;
    RenderStyle "Translucent";
    Alpha 0.7;
    Scale 0.2;
  }

  States {
    Spawn:
      TNT1 A 1;
      TNT1 A 0 A_Explode(0, 0, XF_NOSPLASH, false, 0, fragments, damage,
        "::FragmentationShots::Puff");
      TNT1 A 0 A_AlertMonsters();
      // TODO: include a suitable sound effect
      TNT1 A 0 A_StartSound("imp/shotx", CHAN_WEAPON, CHANF_OVERLAP, 1, 0.5);
      TNT1 A 0 A_StartSound("imp/shotx", CHAN_7, CHANF_OVERLAP, 0.1, 0.01);
      LFRG CDE 2;
      STOP;
  }
}

class ::FragmentationShots::Puff : BulletPuff {
  property UpgradePriority: special1;
  Default {
    ::FragmentationShots::Puff.UpgradePriority ::PRI_FRAGMENTATION;
  }
  States {
    Spawn:
      LPUF A 4 Bright;
      LPUF B 4;
      // Intentional fall-through
    Melee:
      LPUF CD 4;
      STOP;
  }
}

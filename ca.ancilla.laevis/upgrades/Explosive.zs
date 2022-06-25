#namespace TFLV::Upgrade;

class ::ExplosiveShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    bool ok;
    Actor act;
    [ok, act] = shot.A_SpawnItemEx("::ExplosiveShots::Boom");
    let boom = ::ExplosiveShots::Boom(act);
    boom.target = pawn;
    boom.damage = damage * level * 0.4;
    boom.radius = 64 + 16 * level;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsHitscanWeapon() && !info.weapon.bMELEEWEAPON;
  }
}

class ::ExplosiveShots::Boom : Actor {
  uint level;
  uint damage;
  uint radius;

  Default {
    // +PROJECTILE; can't set this in zscript?
    +NOBLOCKMAP;
    +NOGRAVITY;
    +MISSILE;
    +NODAMAGETHRUST;
    +INCOMBAT; // Laevis recursion guard
    DamageType "Extreme";
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    if (target == self.target) {
      return damage * (0.50 ** self.level);
    }
    return damage;
  }

  States {
    Spawn:
      TNT1 A 1;
      TNT1 A 0 A_Explode(damage, radius);
      TNT1 A 0 A_AlertMonsters();
      TNT1 A 0 A_StartSound("imp/shotx", CHAN_WEAPON, CHANF_OVERLAP, 1, 0.5);
      TNT1 A 0 A_StartSound("imp/shotx", CHAN_7, CHANF_OVERLAP, 0.1, 0.01);
      LFBX ABC 7;
      STOP;
  }
}

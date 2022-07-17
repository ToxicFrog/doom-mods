#namespace TFLV::Upgrade;
#debug on

class ::Submunitions : ::BaseUpgrade {
  override ::UpgradePriority Priority() { return ::PRI_EXPLOSIVE; }

  override void OnKill(Actor player, Actor shot, Actor target) {
    let aux = ::Submunitions::Spawner(target.Spawn("::Submunitions::Spawner", target.pos));
    aux.special1 = Priority();
    aux.target = player;
    aux.level = level;
    aux.damage = (target.SpawnHealth() + abs(target.health)) * (1.0 - 0.8 ** level);
    aux.radius = 30;
    DEBUG("Created SubmunitionSpawner");
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
    // return !info.weapon.bMELEEWEAPON;
  }
}

class ::Submunitions::Spawner : Actor {
  uint level;
  uint damage;
  uint radius;

  States {
    Spawn:
      TNT1 A 7;
      TNT1 A 0 SpawnMunitions();
      STOP;
  }

  void SpawnMunitions() {
    for (uint i = 0; i < level * 4; ++i) {
      let aux = ::Submunitions::Aux(target.A_SpawnProjectile(
        "::Submunitions::Aux", 32, 0, random(0,360),
        CMF_AIMDIRECTION|CMF_ABSOLUTEANGLE));
      aux.special1 = special1;
      aux.target = target;
      aux.level = level;
      aux.damage = damage;
      aux.radius = radius;
      DEBUG("Created submunition: level=%d power=%d overkill=%d",
        aux.level, aux.damage, abs(target.health));
    }
  }
}

class ::Submunitions::Aux : Actor {
  uint level;
  uint damage;
  uint radius;

  Default {
    Radius 30;
    Height 60;
    Speed 15;
    Scale 0.4;
    DamageType "Extreme";
    Projectile;
    +FLOORHUGGER;
    +SEEKERMISSILE;
    BounceType "Doom";
    BounceFactor 1.0;
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    if (target == self.target) {
      return damage * (0.5 ** self.level);
    }
    return damage;
  }

  States {
    Spawn:
      PINS DCBA 7 A_SeekerMissile(1, 1, SMF_LOOK);
      LOOP;
    Death:
      LFBX A 0 A_Explode(damage, radius, XF_HURTSOURCE|XF_NOSPLASH);
      LFBX A 0 A_AlertMonsters();
      // TODO: include a suitable sound effect
      TNT1 A 0 A_StartSound("imp/shotx", CHAN_WEAPON, CHANF_OVERLAP, 1, 0.5);
      TNT1 A 0 A_StartSound("imp/shotx", CHAN_7, CHANF_OVERLAP, 0.1, 0.01);
      LFBX ABC 7 Bright;
      STOP;
  }
}

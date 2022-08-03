#namespace TFLV::Upgrade;

class ::Submunitions : ::BaseUpgrade {
  override ::UpgradePriority Priority() { return ::PRI_EXPLOSIVE; }

  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    let aux = ::Submunitions::Spawner(target.Spawn("::Submunitions::Spawner", target.pos));
    aux.special1 = Priority();
    aux.target = player;
    aux.tracer = target;
    aux.level = level;
    aux.damage = abs(target.health) + 5*level; // (target.SpawnHealth()) * (1.0 - 0.8 ** level);
    aux.blast_radius = target.radius*3;
    DEBUG("Created SubmunitionSpawner");
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return !info.weapon.bMELEEWEAPON;
  }
}

class ::Submunitions::Spawner : Actor {
  uint level;
  uint damage;
  uint blast_radius;

  States {
    Spawn:
      TNT1 A 7;
      TNT1 A 0 SpawnMunitions();
      STOP;
  }

  void SpawnMunitions() {
    for (uint i = 0; i < level * 4; ++i) {
      if (!tracer) break;
      let aux = ::Submunitions::Grenade(tracer.A_SpawnProjectile(
        "::Submunitions::Grenade", 32, 0, random(0,360),
        CMF_AIMDIRECTION|CMF_ABSOLUTEANGLE));
      aux.special1 = special1;
      aux.target = target;
      aux.level = level;
      aux.damage = damage;
      aux.blast_radius = blast_radius;
      DEBUG("Created submunition: level=%d power=%d",
        aux.level, aux.damage);
    }
  }
}

class ::Submunitions::Grenade : Actor {
  uint level;
  uint damage;
  uint lifetime;
  uint blast_radius;

  Default {
    Radius 12;
    Height 24;
    Speed 15;
    Scale 0.4;
    DamageType "Extreme";
    Projectile;
    // +FLOORHUGGER;
    +SEEKERMISSILE;
    +NODAMAGETHRUST;
    -NOGRAVITY;
    BounceType "Grenade";
    BounceFactor 1.0;
  }

  override void PostBeginPlay() {
    // Counts down five times a second, so this gives it a duration of 5 seconds
    // per level.
    self.ReactionTime = level * 5 * 5;
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    if (target == self.target) {
      return 1;
    }
    return damage;
  }

  States {
    Spawn:
      LSUB DCBA 7 A_CountDown();
      LOOP;
    Death:
      LFBX A 0 A_Explode(damage, blast_radius, XF_NOSPLASH, false, blast_radius/4);
      LFBX A 0 A_AlertMonsters();
      LFBX A 0 A_StartSound("bonsai/smallboom", CHAN_WEAPON, CHANF_OVERLAP, 1, 0.5);
      LFBX A 0 A_StartSound("bonsai/smallboom", CHAN_7, CHANF_OVERLAP, 0.1, 0.01);
      LFBX ABC 7 Bright;
      STOP;
  }
}

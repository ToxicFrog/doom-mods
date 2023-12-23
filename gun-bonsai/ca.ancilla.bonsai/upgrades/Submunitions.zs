#namespace TFLV::Upgrade;

class ::Submunitions : ::BaseUpgrade {
  override ::UpgradePriority Priority() { return ::PRI_EXPLOSIVE; }

  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    if (shot is "::Submunitions::Grenade") return;
    let aux = ::Submunitions::Spawner(target.Spawn("::Submunitions::Spawner", target.pos));
    aux.weaponspecial = Priority();
    aux.target = player;
    let count = 3+level;
    aux.ReactionTime = count;
    aux.damage = ((target.SpawnHealth() + abs(target.health)) * (1.0 - 0.8 ** level))/count + 4*level;
    aux.blast_radius = target.radius*2.5;
    aux.ttl = level*5; // in seconds
    DEBUG("Created SubmunitionSpawner, damage=%d", aux.damage);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return !info.IsMelee();
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("count", ""..(3 + level));
    fields.insert("bonusdamage", ""..(level * 4));
    fields.insert("damage", AsPercent(1.0 - 0.8 ** level));
    fields.insert("ttl", AsSeconds(level*5*35));
  }
}

class ::Submunitions::Spawner : Actor {
  uint damage;
  uint blast_radius;
  uint ttl;

  States {
    Spawn:
      TNT1 A 7;
    SpawnMunition:
      TNT1 A 1 SpawnMunition();
      TNT1 A 0 A_CountDown();
      LOOP;
  }

  void SpawnMunition() {
    let aux = ::Submunitions::Grenade(A_SpawnProjectile(
      "::Submunitions::Grenade", 32, 0, random[::RNG_GrenadeAngle](0,360),
      CMF_AIMDIRECTION|CMF_ABSOLUTEANGLE));
    aux.weaponspecial = weaponspecial;
    aux.target = target;
    aux.damage = damage;
    aux.blast_radius = blast_radius;
    aux.ReactionTime = ttl*5 + random[::RNG_GrenadeTimer](0,5); // bomblets tick 5 times a second, so multiply by 5
    DEBUG("Created submunition: level=%d power=%d",
      aux.level, aux.damage);
  }
}

class ::Submunitions::Grenade : Actor {
  uint damage;
  uint blast_radius;
  property UpgradePriority: weaponspecial;

  Default {
    ::Submunitions::Grenade.UpgradePriority ::PRI_EXPLOSIVE;
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
      LFBX A 0 A_Explode(damage, blast_radius, XF_NOSPLASH, false, blast_radius);
      LFBX A 0 A_AlertMonsters();
      LFBX A 0 A_StartSound("bonsai/smallboom", CHAN_WEAPON, CHANF_OVERLAP, 1, 0.5);
      LFBX A 0 A_StartSound("bonsai/smallboom", CHAN_7, CHANF_OVERLAP, 0.1, 0.01);
      LFBX ABC 7 Bright;
      STOP;
  }
}

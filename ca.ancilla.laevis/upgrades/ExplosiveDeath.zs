#namespace TFLV::Upgrade;
#debug off

class ::ExplosiveDeath : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    let aux = ::ExplosiveDeath::Aux(target.Spawn("::ExplosiveDeath::Aux", target.pos));
    aux.target = player;
    aux.level = level;
    aux.power = (target.SpawnHealth() + abs(target.health)) * (1.0 - 0.8 ** level);
    DEBUG("Created explosion: level=%d power=%d overkill=%d",
      aux.level, aux.power, abs(target.health));
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return !info.weapon.bMELEEWEAPON;
  }
}

class ::ExplosiveDeath::Aux : Actor {
  uint level;
  uint power;

  Default {
    DamageType "Extreme";
    +NOBLOCKMAP;
    +NOGRAVITY;
    +INCOMBAT; // Laevis recursion guard
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    if (target == self.target) {
      return damage * (0.5 ** self.level);
    }
    return damage;
  }

  States {
    Spawn:
      LEXP B 7 Bright NoDelay A_Explode(power, 64 + level*32, XF_HURTSOURCE, false, level*16);
      LEXP CD 7 Bright;
      STOP;
  }
}

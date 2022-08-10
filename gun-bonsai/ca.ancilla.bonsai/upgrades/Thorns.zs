#namespace TFLV::Upgrade;
#debug off;

class ::Thorns : ::BaseUpgrade {
  ::Thorns::Aux aux;

  override void OnDamageReceived(Actor pawn, Actor shot, Actor attacker, int damage) {
    if (!attacker || pawn == attacker || !attacker.bISMONSTER || attacker.bFRIENDLY) return;
    // Create once and keep it around.
    if (!aux) aux = ::Thorns::Aux(pawn.Spawn("::Thorns::Aux"));
    aux.Retaliate(pawn, level, attacker, damage);
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

// We have a special actor for actually inflicting the thorns damage so that we
// can set its weaponspecial field according to whether we want thorns retaliation
// to proc elemental effects or not.
class ::Thorns::Aux : Actor {
  property UpgradePriority: weaponspecial;

  Default {
    RenderStyle "None";
    +NOBLOCKMAP;
    +NOGRAVITY;
  }

  void Retaliate(Actor player, uint level, Actor attacker, int damage) {
    let range = player.Distance3D(attacker);
    double min_radius = 192*level;
    double max_radius = 1024*level;
    if (max_radius < range) return;
    double multiplier = (1 - max(0, range-min_radius)/(max_radius-min_radius));
    self.weaponspecial = multiplier >= 0.9/level ? ::PRI_THORNS : ::PRI_NULL;
    DEBUG("Retaliation vs. %s for %d damage, range is %d - %d - %d, mul=%.2f",
      TAG(attacker), damage, min_radius, range, max_radius, multiplier);
    attacker.DamageMobj(self, player,
      max(level, damage * (level+1) * multiplier), "Thorns", DMG_THRUSTLESS);
  }
}

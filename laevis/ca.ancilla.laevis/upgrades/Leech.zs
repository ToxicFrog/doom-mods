// TODO: might want to have separate weapon and player leeches with different
// stats.
#namespace TFLV::Upgrade;

class ::LifeLeech : ::BaseUpgrade {
  double leech;
  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    leech += (damage * level * 0.01);
    if (leech >= 1) {
      pawn.GiveInventory("Health", floor(leech));
      leech = leech - floor(leech);
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

class ::ArmourLeech : ::BaseUpgrade {
  double leech;
  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    leech += (damage * level * 0.02);
    if (leech >= 1) {
      pawn.GiveInventory("ArmorBonus", floor(leech));
      leech = leech - floor(leech);
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

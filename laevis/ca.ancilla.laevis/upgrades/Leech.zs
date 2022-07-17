// Health & armour leech abilities.
// Actually cause enemies to drop bonus health/armour on death. Amount depends
// on how powerful the enemy was.
#namespace TFLV::Upgrade;

class ::LifeLeech : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    let hp = ::LifeLeech::Bonus(target.Spawn(
      "::LifeLeech::Bonus",
      (target.pos.x + random(-target.radius/2, target.radius/2),
       target.pos.y + random(-target.radius/2, target.radius/2),
       target.pos.z + target.height/2)));
    hp.amount = target.SpawnHealth() * 0.01 * level;
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

class ::LifeLeech::Bonus : HealthBonus {
  States {
    Spawn:
      LBHP ABCDCB 6;
      LOOP;
  }
}

class ::ArmourLeech : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    let ap = ::ArmourLeech::Bonus(target.Spawn("::ArmourLeech::Bonus", target.pos));
    ap.SaveAmount = target.SpawnHealth() * 0.02 * level;
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

class ::ArmourLeech::Bonus : ArmorBonus {
  States {
    Spawn:
      LBAP ABCDCB 6;
      LOOP;
  }
}

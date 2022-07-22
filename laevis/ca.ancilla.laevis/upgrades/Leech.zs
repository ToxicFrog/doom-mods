// Health & armour leech abilities.
// Actually cause enemies to drop bonus health/armour on death. Amount depends
// on how powerful the enemy was.
#namespace TFLV::Upgrade;

class ::LeechUtil {
  clearscope static Vector3 WigglePos(Actor act) {
    return (
      act.pos.x + random(-act.radius/2, act.radius/2),
      act.pos.y + random(-act.radius/2, act.radius/2),
      act.pos.z + act.height/2
    );
  }
}

class ::LifeLeech : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    let hp = ::LifeLeech::Bonus(target.Spawn(
      "::LifeLeech::Bonus", ::LeechUtil.WigglePos(target)));
    hp.amount = max(1, target.SpawnHealth() * 0.01 * level);
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
    let ap = ::ArmourLeech::Bonus(target.Spawn(
      "::ArmourLeech::Bonus", ::LeechUtil.WigglePos(target)));
    ap.SaveAmount = max(1, target.SpawnHealth() * 0.01 * level);
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

class ::AmmoLeech : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    Array<Ammo> candidates;
    for (Inventory inv = player.inv; inv != null; inv = inv.inv) {
      if (inv is "Ammo") {
        DEBUG("Candidate: %s", inv.GetTag());
        candidates.push(Ammo(inv));
      }
    }
    if (candidates.size() == 0) return;
    for (uint i = 0; i < level; ++i) {
      let chosen = candidates[random(0, candidates.size()-1)];
      DEBUG("Spawning %s", chosen.GetTag());
      target.Spawn(chosen.GetClassName(), ::LeechUtil.WigglePos(target));
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

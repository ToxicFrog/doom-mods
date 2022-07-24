// Health & armour leech abilities.
// Actually cause enemies to drop bonus health/armour on death. Amount depends
// on how powerful the enemy was.
#namespace TFLV::Upgrade;

class ::LeechUtil {
  clearscope static Vector3 WigglePos(Actor act) {
    return (
      act.pos.x + random(-act.radius/1.4, act.radius/1.4),
      act.pos.y + random(-act.radius/1.4, act.radius/1.4),
      act.pos.z + random(act.height/4, act.height)
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
  Default {
    -COUNTITEM;
  }
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
  Default {
    -COUNTITEM;
  }
  States {
    Spawn:
      LBAP ABCDCB 6;
      LOOP;
  }
}

class ::AmmoLeech : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    Array<String> candidates;
    for (Inventory inv = player.inv; inv != null; inv = inv.inv) {
      let wpn = Weapon(inv);
      if (wpn) {
        if (wpn.AmmoType1) candidates.push(wpn.AmmoType1.GetClassName());
        if (wpn.AmmoType2) candidates.push(wpn.AmmoType2.GetClassName());
      }
    }
    if (candidates.size() == 0) return;
    for (uint i = 0; i < level; ++i) {
      let chosen = candidates[random(0, candidates.size()-1)];
      DEBUG("Spawning %s", chosen);
      let ammo = target.Spawn(chosen, ::LeechUtil.WigglePos(target));
      ammo.bCOUNTITEM = false;
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

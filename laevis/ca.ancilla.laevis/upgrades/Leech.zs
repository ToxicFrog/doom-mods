// Health & armour leech abilities.
// Actually cause enemies to drop bonus health/armour on death. Amount depends
// on how powerful the enemy was.
#namespace TFLV::Upgrade;
#debug off

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
    Scale 0.07;
    RenderStyle "Add";
  }
  States {
    Spawn:
      LHP1 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
      LHP2 ABCDEFGH 2;
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
    Scale 0.07;
    RenderStyle "Add";
  }
  States {
    Spawn:
      LAP1 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
      LAP2 ABCDEFGH 2;
      LOOP;
  }
}

class ::AmmoLeech : ::BaseUpgrade {
  bool IsSuitable(Class<Ammo> atype) {
    return atype && GetDefaultByType(atype).FindState("Spawn").Sprite != 0;
  }

  override void OnKill(Actor player, Actor shot, Actor target) {
    Array<String> candidates;
    for (Inventory inv = player.inv; inv != null; inv = inv.inv) {
      let wpn = Weapon(inv);
      if (wpn) {
        DEBUG("Considering %s", TAG(wpn));
        if (IsSuitable(wpn.AmmoType1)) {
          candidates.push(wpn.AmmoType1.GetClassName());
          DEBUG("Primary ammo: %s (%d)",
            wpn.AmmoType1.GetClassName(),
            GetDefaultByType(wpn.AmmoType1).Amount);
        }
        if (IsSuitable(wpn.AmmoType2)) {
          candidates.push(wpn.AmmoType2.GetClassName());
          DEBUG("Secondary ammo: %s (%d)",
            wpn.AmmoType2.GetClassName(),
            GetDefaultByType(wpn.AmmoType2).Amount);
        }
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

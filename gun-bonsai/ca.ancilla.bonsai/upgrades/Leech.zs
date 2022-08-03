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
    let hp = Health(target.Spawn(
      GetBonusName(), ::LeechUtil.WigglePos(target), ALLOW_REPLACE));
    if (!hp) return;
    hp.amount = target.bBOSS ? level*10 : level;
    hp.maxamount = clamp(100*level, 100, 200);
  }

  string GetBonusName() {
    if (TFLV::Settings.use_builtin_actors()) {
      return "::LifeLeech::Bonus";
    } else {
      return "HealthBonus";
    }
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
    Inventory.PickupMessage "";
  }
  States {
    Spawn:
      LHP1 A 3 Light("SCAVBLOODLIGHT");
      LHP1 BCDEFGHIJKLMNOPQRSTUVWXYZ 2 Light("SCAVBLOODLIGHT");
      LHP2 ABCDEFGH 2 Light("SCAVBLOODLIGHT");
      LOOP;
  }
}

class ::ArmourLeech : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    let ap = BasicArmorBonus(target.Spawn(
      GetBonusName(), ::LeechUtil.WigglePos(target), ALLOW_REPLACE));
    if (!ap) return;
    ap.SaveAmount = target.bBOSS ? level*20 : level*2;
    ap.MaxSaveAmount = clamp(100*level, 100, 200);
  }

  string GetBonusName() {
    if (TFLV::Settings.use_builtin_actors()) {
      return "::ArmourLeech::Bonus";
    } else {
      return "ArmorBonus";
    }
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
    Inventory.PickupMessage "";
  }
  States {
    Spawn:
      LAP1 A 3 Light("SCAVSTEELLIGHT");
      LAP1 BCDEFGHIJKLMNOPQRSTUVWXYZ 2 Light("SCAVSTEELLIGHT");
      LAP2 ABCDEFGH 2 Light("SCAVSTEELLIGHT");
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

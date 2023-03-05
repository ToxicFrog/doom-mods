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
  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    let hp = Health(target.Spawn(
      GetBonusName(), ::LeechUtil.WigglePos(target), ALLOW_REPLACE));
    if (!hp) return;
    let cap = player.GetMaxHealth(true);
    hp.amount = target.bBOSS ? level*10 : level;
    hp.maxamount = clamp(cap * level, cap, 2*cap);
    DEBUG("hp=%d/%d (base: %d)", hp.amount, hp.maxamount, cap);
  }

  string GetBonusName() {
    if (bonsai_use_builtin_actors) {
      return "::LifeLeech::Bonus";
    } else {
      return "HealthBonus";
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("amount", ""..level);
    fields.insert("cap", AsPercent(level >= 2 ? 2 : 1));
  }
}

class ::LifeLeech::Bonus : HealthBonus {
  Default {
    -COUNTITEM;
    Scale 0.07;
    RenderStyle "Add";
    Radius 32;
    Inventory.PickupMessage "";
    Inventory.Amount 1;
    Inventory.MaxAmount 100;
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
  uint armour_cap;

  override void OnPickup(PlayerPawn pawn, Inventory item) {
    let armour = BasicArmorPickup(item);
    if (!armour) return;
    armour_cap = max(self.armour_cap, armour.SaveAmount);
  }

  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
    let ap = BasicArmorBonus(target.Spawn(
      GetBonusName(), ::LeechUtil.WigglePos(target), ALLOW_REPLACE));
    if (!ap) return;
    uint cap = (armour_cap ? armour_cap : player.GetMaxHealth(true));
    ap.SaveAmount = target.bBOSS ? level*20 : level*2;
    ap.MaxSaveAmount = clamp(cap * level, cap, 2*cap);
    DEBUG("ap=%d/%d (base: %d)", ap.SaveAmount, ap.MaxSaveAmount, cap);
  }

  string GetBonusName() {
    if (bonsai_use_builtin_actors) {
      return "::ArmourLeech::Bonus";
    } else {
      return "ArmorBonus";
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("amount", ""..(level*2));
    fields.insert("cap", AsPercent(level >= 2 ? 2 : 1));
  }
}

class ::ArmourLeech::Bonus : BasicArmorBonus {
  Default {
    -COUNTITEM;
    Scale 0.07;
    RenderStyle "Add";
    Radius 32;
    Inventory.PickupMessage "";
    Armor.SaveAmount 2;
    Armor.MaxSaveAmount 100;
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

  float AmmoFactor(Actor target) {
    // 1x per thousand hitpoints. Minimum of 20%.
    return max(target.GetSpawnHealth()/1000.0, 0.2);
  }

  override void OnKill(PlayerPawn player, Actor shot, Actor target) {
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
      let ammo = target.Spawn(chosen, ::LeechUtil.WigglePos(target), ALLOW_REPLACE);
      ammo.bCOUNTITEM = false;
      let ammoitem = Inventory(ammo);
      if (ammoitem) {
        // Adjust quantity, for ammo drops where we know how to do so.
        // We drop ¼ as much ammo as normal.
        // If this results in fractional ammo, roll the dice; a drop of 1 has a
        // 25% chance to appear at all, a drop of 10 will be 2 half the time and
        // 3 half the time.
        float amount = ammoitem.amount * AmmoFactor(target);
        ammoitem.amount = floor(amount);
        float partial = amount % 1.0;
        if (partial > 0.0 && frandom(0.0, 1.0) <= partial) ammoitem.amount += 1;
        if (ammoitem.amount == 0) ammo.Destroy();
      }
    }
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("amount", ""..level);
  }
}

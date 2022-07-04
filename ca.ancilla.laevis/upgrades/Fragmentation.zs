#namespace TFLV::Upgrade;
#debug on

class ::FragmentationShots : ::BaseUpgrade {
  override ::UpgradePriority Priority() { return ::PRI_FRAGMENTATION; }

  override void OnProjectileCreated(Actor pawn, Actor shot) {
    shot.GiveInventoryType("::FragmentationShots::Marker");
    DEBUG("Tagging %s", shot.GetTag());
    DEBUG("Shot inventory: %s", TFLV::Util.SafeTag(shot.inv));
  }

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    // Trigger only once for each shot, so that e.g. a rocket spawns one blast of
    // fragments, rather than one blast per enemy damaged by it.
    // Ideally we'd put this in OwnerDied on the shot itself, but apparently shots
    // disincorporating because they hit something don't trigger that function.
    if (!shot || !shot.FindInventory("::FragmentationShots::Marker")) return;
    shot.TakeInventory("::FragmentationShots::Marker", 999);

    // TODO: new Upgrade-specific Spawn function that sets special1
    // and target appropriately.
    DEBUG("OnDamageDealt, source=%s", shot.GetTag());
    let boom = ::FragmentationShots::Boom(shot.Spawn("::FragmentationShots::Boom", shot.pos));
    boom.special1 = Priority();
    boom.target = pawn;
    boom.level = level;
    boom.damage = ceil(damage * 0.2);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsProjectileWeapon() && !info.weapon.bMELEEWEAPON;
  }
}

class ::FragmentationShots::Marker : Inventory {
  property Priority: special1;
  Default { ::FragmentationShots::Marker.Priority ::PRI_FRAGMENTATION; }
}

class ::FragmentationShots::Boom : Actor {
  uint level;
  uint damage;

  Default {
    +NOBLOCKMAP;
    +NOGRAVITY;
    +NODAMAGETHRUST;
    RenderStyle "Translucent";
    Alpha 0.7;
    Scale 0.2;
  }

  States {
    Spawn:
      TNT1 A 3; // the fragments take a few millis to travel
      TNT1 A 0 A_Explode(0, 0, XF_NOSPLASH, false, 0, 8+level*8, damage,
        "::FragmentationShots::Puff");
      TNT1 A 0 A_AlertMonsters();
      // TODO: include a suitable sound effect
      TNT1 A 0 A_StartSound("imp/shotx", CHAN_WEAPON, CHANF_OVERLAP, 1, 0.5);
      TNT1 A 0 A_StartSound("imp/shotx", CHAN_7, CHANF_OVERLAP, 0.1, 0.01);
      LFRG CDE 2;
      STOP;
  }
}

class ::FragmentationShots::Puff : BulletPuff {
  property UpgradePriority: special1;
  Default {
    ::FragmentationShots::Puff.UpgradePriority ::PRI_FRAGMENTATION;
    +ALWAYSPUFF;
  }
  States {
    Spawn:
      LPUF A 4 Bright;
      LPUF B 4;
      // Intentional fall-through
    Melee:
      LPUF CD 4;
      STOP;
  }
}

#namespace TFLV::Upgrade;
#debug off

class ::FragmentationShots : ::BaseUpgrade {
  override ::UpgradePriority Priority() { return ::PRI_FRAGMENTATION; }

  override void OnProjectileCreated(Actor pawn, Actor shot) {
    shot.GiveInventoryType("::FragmentationShots::Marker");
    DEBUG("Tagging %s", shot.GetTag());
    DEBUG("Shot inventory: %s", TAG(shot));
  }

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    // Trigger only once for each shot, so that e.g. a rocket spawns one blast of
    // fragments, rather than one blast per enemy damaged by it.
    // Ideally we'd put this in OwnerDied on the shot itself, but apparently shots
    // disincorporating because they hit something don't trigger that function.
    if (!shot || !shot.FindInventory("::FragmentationShots::Marker")) return;
    shot.TakeInventory("::FragmentationShots::Marker", 999);

    // TODO: new Upgrade-specific Spawn function that sets weaponspecial
    // and target appropriately.
    DEBUG("OnDamageDealt, source=%s", shot.GetTag());
    let boom = ::FragmentationShots::Boom(shot.Spawn("::FragmentationShots::Boom", shot.pos));
    boom.weaponspecial = Priority();
    boom.target = pawn;
    boom.tracer = target; // So that it knows which enemy to ignore
    boom.level = level;
    boom.damage = ceil(damage * 0.2);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsProjectile()
      && !info.IsRipper()
      && !info.IsMelee();
  }
  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("fragments", ""..(8*level+8));
  }
}

class ::FragmentationShots::Marker : Inventory {
  property Priority: weaponspecial;
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
    Alpha 0.5;
    Scale 1.0;
  }

  void Explode() {
    let nfragments = 8 + level*8;
    for (uint i = 0; i < nfragments; ++i) {
      double angle = 360.0/nfragments * i;
      let aux = ::FragmentationShots::Fragment(
        A_SpawnProjectile(
          "::FragmentationShots::Fragment",
          0, 0, angle,
          CMF_AIMDIRECTION|CMF_TRACKOWNER,
          random(-1.0,1.0)));
      aux.target = self.target;
      aux.tracer = self.tracer;
      aux.customdamage = self.damage;
      aux.bTHRUACTORS = false;
      DEBUG("Spawned projectile %s angle=%d target=%s tracer=%s damage=%d",
        TAG(aux), angle, TAG(aux.target), TAG(aux.tracer), aux.damage);
    }
  }

  States {
    Spawn:
      TNT1 A 3; // the fragments take a few millis to travel
      TNT1 A 0 Explode();
      LFRG CDE 2;
      STOP;
  }
}

class ::FragmentationShots::Fragment : FastProjectile {
  uint customdamage;
  property UpgradePriority: weaponspecial;
  Default {
    ::FragmentationShots::Fragment.UpgradePriority ::PRI_FRAGMENTATION;
    Radius 2;
    Height 2;
    Speed 30;
    Damage 1; // uses customdamage via DoSpecialDamage() instead
    MissileType "::FragmentationShots::Trail";
    MissileHeight 8;
    Scale 0.4;
    Alpha 0.9;
    RenderStyle "Add";
    PROJECTILE;
    +THRUACTORS; // used to disable collision when first spawned; gets turned on after.
  }

  States {
    Spawn:
      LPUF A 1 BRIGHT;
      LOOP;
    Crash:
    Death:
      LPUF ABCD 2 BRIGHT;
      STOP;
    XDeath:
      STOP;
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    return customdamage;
  }

  override bool CanCollideWith(Actor other, bool passive) {
    // Don't collide with the player, or with the monster they just shot.
    DEBUG("CanCollide? other=%s target=%s tracer=%s other=target? %d other=tracer? %d",
      TAG(other), TAG(self.target), TAG(self.tracer), other == self.target, other == self.tracer);
    return other != self.tracer && other != self.target;
  }
}

class ::FragmentationShots::Trail : Actor {
  Default {
    Speed 0;
    Scale 0.4;
    Alpha 0.75;
    RenderStyle "Add";
    +NOBLOCKMAP;
    +NOGRAVITY;
    +NOTELEPORT;
    +CANNOTPUSH;
    +NODAMAGETHRUST;
  }

  States {
    Spawn:
      LPUF A 1 BRIGHT A_FadeOut(0.3);
      LOOP;
  }
}


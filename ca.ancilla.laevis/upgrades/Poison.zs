#namespace TFLV::Upgrade;

class ::PoisonShots : ::BaseUpgrade {
  override void OnDamageDealt(Actor player, Actor shot, Actor target, int damage) {
    if (!shot) return;
    ::Dot.GiveStacks(player, target, "::Poison", level*10);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }
}

class ::Poison : ::Dot {
  Default {
    DamageType "Poison";
    Inventory.Amount 10;
    +INCOMBAT; // Laevis recursion guard
  }

  override string GetParticleColour() {
    static const string colours[] = { "green", "green1", "black" };
    return colours[random(0,2)];
  }

  override double GetParticleZV() {
    return -0.1;
  }

  override uint GetDamage() {
    if (amount <= 0) {
      Destroy();
      return 0;
    }
    // DEBUG("poison stacks=%d damage=%d", amount, (amount-1)/5);
    return (amount--)/5;
  }
}

class ::Putrefaction : ::BaseUpgrade {
  override void OnKill(Actor player, Actor shot, Actor target) {
    uint amount = ::Dot.CountStacks(target, "::Poison");
    DEBUG("killed %s, poison stacks=%d", TFLV::Util.SafeCls(target), amount);
    if (amount == 0) return;

    bool ok; Actor act;
    [ok, act] = target.A_SpawnItemEx(
      "::Putrefaction::Aux",
      0, 0, 0, 0, 0, 0, 0,
      SXF_TRANSFERPOINTERS);
    let poison = ::Putrefaction::Aux(act);
    poison.target = player;
    poison.level = max(amount/2, 1);
    DEBUG("spawned putrefaction cloud with level=%d", poison.level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.upgrades.Level("::PoisonShots") >= 2 && info.upgrades.Level("::Putrefaction") == 0;
  }
}

class ::Putrefaction::Aux : Actor {
  uint level;

  Default {
    RenderStyle "Translucent";
    Alpha 0.4;
  }

  override int DoSpecialDamage(Actor target, int damage, Name damagetype) {
    ::Dot.GiveStacks(self.target, target, "::Poison", 1, level);
    return 0;
  }
  States {
    Spawn:
      LPBX ABABABCBCBCDCDCDEE 7 A_Explode(100, 100, XF_NOSPLASH, false, 100);
      STOP;
  }
}

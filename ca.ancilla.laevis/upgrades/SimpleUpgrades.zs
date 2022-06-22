// Simple upgrades that don't need any aux classes and have simple implementations
#namespace TFLV::Upgrade;

class ::Damage : ::BaseUpgrade {
  override double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    return damage * (1.0 + self.level * TFLV_Settings.player_damage_bonus());
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return true;
  }
}

class ::FastShots : ::BaseUpgrade {
  override void OnProjectileCreated(Actor player, Actor shot) {
    shot.A_ScaleVelocity(1 + 0.5*level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsProjectileWeapon();
  }
}

class ::Resistance : ::BaseUpgrade {
  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    return damage * (TFLV::Settings.player_defence_bonus() ** self.level);
  }

  override bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return true;
  }
}

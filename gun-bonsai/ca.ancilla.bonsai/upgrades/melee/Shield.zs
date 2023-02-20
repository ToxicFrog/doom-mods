#namespace TFLV::Upgrade;
#debug off;

// While attacking in melee, gives you large % resistance to melee attacks and
// smaller % resistance to ranged attacks. This resistance lasts small seconds
// after you stop attacking and large seconds after a kill; more kills reset the
// timer but do not stack.
class ::Shield : ::BaseUpgrade {
  // Timer for when the shield is active.
  uint ticks;
  override void Tick(Actor owner) {
    if (ticks) --ticks;
  }

  override void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    ticks = max(ticks, AttackTTL(level));
  }
  override void OnKill(PlayerPawn pawn, Actor shot, Actor target) {
    ticks = max(ticks, KillTTL(level));
  }

  override double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage, Name attacktype) {
    DEBUG("Shield: ticks=%d", ticks);
    if (!ticks) return damage;
    let range = pawn.Distance3D(attacker);
    double short_range = ShortRange(level);
    double long_range = LongRange(level);
    double short_factor = MeleeDamageFactor(level);
    double long_factor = RangedDamageFactor(level);

    // linear interpolation between melee and ranged damage reduction
    let interpolation = clamp((range - short_range)/(long_range - short_range), 0.0, 1.0);
    let factor = short_factor + (long_factor - short_factor) * interpolation;
    DEBUG("Attacker %s at range %.1f, damage factor is %.2f", TAG(attacker), range, factor);
    DEBUG("short=%f long=%f range=%f interpolation=%f", short_range, long_range, range, interpolation);
    return damage * factor;
  }

  static uint ShortRange(uint level) {
    return 128; // 4m
  }
  static uint LongRange(uint level) {
    return ShortRange(level) * (2.0 + 0.25 * (level-1));
  }
  static double MeleeDamageFactor(uint level) {
    return 0.6**level;
  }
  static double RangedDamageFactor(uint level) {
    return 0.85**level;
  }
  static uint AttackTTL(uint level) {
    return 35 + level*21;
  }
  static uint KillTTL(uint level) {
    return 35 * (5 + level);
  }

  override bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return info.IsMelee();
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("shortrange", AsMeters(ShortRange(level)));
    fields.insert("longrange", AsMeters(LongRange(level)));
    fields.insert("meleedamagepct", AsPercentDecrease(MeleeDamageFactor(level)));
    fields.insert("rangeddamagepct", AsPercentDecrease(RangedDamageFactor(level)));
    fields.insert("attackttl", string.format("%.1fs", AttackTTL(level)/35.0));
    fields.insert("killttl", string.format("%.1fs", KillTTL(level)/35.0));
  }
}

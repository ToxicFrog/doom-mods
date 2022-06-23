#namespace TFLV::Upgrade;

class ::BaseUpgrade : Object play {
  uint level;

  virtual void Init() {
    level = 1;
  }

  // VIRTUAL FUNCTIONS //

  // Upgrade selection functions.
  // These will be called when generating an upgrade to see if the upgrade should
  // be added to the pool.
  // These can be used to restrict some upgrades to player-only or weapon-only, or
  // require certain prerequisite upgrades or a certain minimum level or the like.
  virtual bool IsSuitableForPlayer(TFLV::PerPlayerStats stats) {
    return false;
  }
  virtual bool IsSuitableForWeapon(TFLV::WeaponInfo info) {
    return false;
  }

  // Event handler functions.
  // Subclasses must override at least one of these to have any effect!

  // Called when the player fires a projectile shot. Note that this is not called
  // for hitscans -- only for stuff like the rocket launcher and plasma rifle.
  // This is the upgrade's chance to modify the projectile in-place by e.g.
  // adding or removing flags.
  virtual void OnProjectileCreated(Actor pawn, Actor shot) {
    return;
  }

  // Event handlers for damage events.
  // Note that in all of these, *pawn* is the player, *target* or *attacker* is
  // the monster; *shot*, if defined, is the projectile or puff associated with
  // the attack, but for things like DoTs it may be null, or an Inventory being
  // held by the monster, or the like, so don't make assumptions about it.

  // Called when the player is about to damage something. Should return the actual
  // amount of damage to deal; this will be converted to int once all ModifyDamage
  // handlers have run.
  // Note that you can't add projectile flags here and have them do anything --
  // to modify projectiles in flight use OnProjectileCreated, and to add on-hit
  // effects (which, for hitscans, is the only way to add effects at all), use
  // OnDamageDealt.
  virtual double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage) {
    return damage;
  }

  // As ModifyDamageDealt but called when something else is about to damage the
  // player.
  virtual double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage) {
    return damage;
  }

  // Called *after* the player damages something. This can be used to apply on-hit
  // effects. The amount of damage passed in is the actual damage dealt, after any
  // ModifyDamage calls have taken effect. Can also be used to check for kills by
  // checking the target's hp.
  virtual void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    return;
  }

  virtual void OnDamageReceived(Actor pawn, Actor shot, Actor target, int damage) {
    return;
  }

  virtual void OnKill(Actor pawn, Actor shot, Actor target) {
    return;
  }

  // INTERNAL DETAILS //
  string GetName() const {
    return StringTable.Localize("$"..self.GetClassName().."_Name");
  }

  string GetDesc() const {
    return StringTable.Localize("$"..self.GetClassName().."_Desc");
  }

  static ::BaseUpgrade GenerateUpgrade() {
    static const string UpgradeNames[] = {
      "::Armour",
      "::ArmourLeech",
      "::Damage",
      "::ExplosiveShots",
      "::FastShots",
      "::HomingShots",
      "::IncendiaryShots",
      "::LifeLeech",
      "::PiercingShots",
      "::PoisonShots",
      "::Pyre",
      "::Resistance"
    };
    let cls = UpgradeNames[random(0, UpgradeNames.Size()-1)];
    return ::BaseUpgrade(new(cls));
  }

  static ::BaseUpgrade GenerateUpgradeForPlayer(TFLV::PerPlayerStats stats) {
    ::BaseUpgrade upgrade = null;
    while (upgrade == null) {
      upgrade = GenerateUpgrade();
      if (upgrade.IsSuitableForPlayer(stats)) return upgrade;
      upgrade.Destroy();
      upgrade = null;
    }
    return null; // unreachable
  }

  static ::BaseUpgrade GenerateUpgradeForWeapon(TFLV::WeaponInfo info) {
    ::BaseUpgrade upgrade = null;
    while (upgrade == null) {
      upgrade = GenerateUpgrade();
      if (upgrade.IsSuitableForWeapon(info)) return upgrade;
      upgrade.Destroy();
      upgrade = null;
    }
    return null; // unreachable
  }

}

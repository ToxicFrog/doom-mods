// Base class for weapon and player upgrades.
// To implement a Laevis upgrade in your own mod:
// - Subclass TFLV_Upgrade_BaseUpgrade
// - Implement at least one of the IsSuitableFor* functions with the conditions
//   needed for the upgrade to spawn
// - Implement at least one of the On* or Modify* functions with the actual
//   effects of the upgrade
// - If your effect should be triggerable by other effects, set an appropriate
//   priority level in Priority()
// - Add the name and description to your LANGUAGE file; the keys should be
//   [upgrade_class_name]_Name and [upgrade_class_name]_Desc, e.g.
//   TFLV_Upgrade_Pyre_Name and TFLV_Upgrade_Pyre_Desc.
// - In your startup code (e.g. in your StaticEventHandler's OnRegister), call
//   TFLV_Upgrade_Registry.Register("upgrade_class_name"). Make sure this runs
//   *after* TFLV_EventHandler or the registry won't exist yet.
// - All done! The upgrade should now start appearing in play when your mod is
//   loaded after Laevis.
// If for some reason you can't register it in a StaticEventHandler -- say you
// have to register it in WorldLoaded() or in an actor's Spawn: state -- it's
// safe to register the same upgrade multiple times; it'll just ignore every
// registration after the first.
#namespace TFLV::Upgrade;

enum ::UpgradePriority {
  ::PRI_NULL = -1,
  ::PRI_MISSING = 0,
  ::PRI_ELEMENTAL,
  ::PRI_EXPLOSIVE,
  ::PRI_FRAGMENTATION
}

class ::BaseUpgrade : Object play {
  uint level;

  // VIRTUAL FUNCTIONS //

  // Tick function. Equivalent to Thinker.Tick() but we define it here because
  // we can't inherit from Thinker and have the upgrades survive level changes.
  virtual void Tick() {}

  // Priority system.
  // The basic idea here is that upgrade effects can only be triggered by (a)
  // events not associated with an upgrade, like normal player attacks, and (b)
  // events associated with a higher-priority upgrade.
  // So, for example, Explosive Shots (PRI_EXPLOSIVE) can proc Poison Shots
  // (PRI_ELEMENTAL), but the poison dot can't trigger the Explosive Shots.
  // Default is lowest priority -- can be triggered by anything, can't trigger
  // anything.
  // In order for this to work right, secondary actors created by upgrade effects
  // need to have their `master` pointer set to the upgrade object that created
  // them.
  // Generally speaking, any upgrade that can be triggered by OnDamage effects
  // should set this to higher than PRI_ELEMENTAL unless it makes sense for it
  // to be triggered by elemental dots, and any upgrade that spawns secondary
  // actors should also set it to higher than PRI_ELEMENTAl so that those actors
  // can proc elemental riders.
  // As a special case, upgrades with PRI_NULL can neither trigger nor be triggered
  // by other upgrades.
  virtual ::UpgradePriority Priority() { return ::PRI_NULL; }
  bool CheckPriority(Actor inflictor) {
    return !inflictor
      || inflictor.special1 == ::PRI_MISSING
      || inflictor.special1 > Priority();
  }

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
}

// TODO: this is pretty gross. It should be generalized so that elemental upgrades
// can answer questions about themselves.
class ::ElementalUpgrade : ::BaseUpgrade {
  override ::UpgradePriority Priority() { return ::PRI_ELEMENTAL; }

  static bool CanAcceptElement(TFLV::WeaponInfo info, string element) {
    string inprogress = GetElementInProgress(info.upgrades);
    return inprogress == element
      || (inprogress == "" && GetElementCount(info.upgrades) < 2);
  }

  static uint GetElementCount(::UpgradeBag upgrades) {
    uint count = 0;
    if (upgrades.Level("::IncendiaryShots") > 0) ++count;
    if (upgrades.Level("::PoisonShots") > 0) ++count;
    if (upgrades.Level("::CorrosiveShots") > 0) ++count;
    return count;
  }

  // A weapon should only ever have one element in progress, so we just return the
  // first one we find.
  static string GetElementInProgress(::UpgradeBag upgrades) {
    if (upgrades.Level("::IncendiaryShots") > 0
        && (upgrades.Level("::Conflagration") + upgrades.Level("::InfernalKiln")) == 0)
      return "Fire";
    if (upgrades.Level("::PoisonShots") > 0
        && (upgrades.Level("::Putrefaction") + upgrades.Level("::Hallucinogens")) == 0)
      return "Poison";
    if (upgrades.Level("::CorrosiveShots") > 0
        && (upgrades.Level("::Embrittlement") + upgrades.Level("::ExplosiveReaction")) == 0)
      return "Acid";
    return "";
  }
}

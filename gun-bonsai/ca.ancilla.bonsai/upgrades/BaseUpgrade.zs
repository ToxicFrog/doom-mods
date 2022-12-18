// Base class for weapon and player upgrades.
// To implement a Gun Bonsai upgrade in your own mod:
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
// - In your startup code, call:
//     TFLV_Upgrade_Registry.GetRegistry().Register("upgrade_class").
//   Make sure this runs *after* TFLV_EventHandler's OnRegister; if unsure,
//   defer it to WorldLoaded or something. It's safe to Register() the same
//   upgrade multiple times.
// - All done! The upgrade should now start appearing in play when your mod is
//   loaded after Gun Bonsai.
#namespace TFLV::Upgrade;
#debug off;

// Upgrade priority levels. Higher priorities can trigger lower priorities,
// but not vice versa.
// So (e.g.) the fragments from Fragmentation Shots (PRI_FRAGMENTATION) can
// proc poison effects (PRI_ELEMENTAL), but the poison DoT won't cause the
// afflicted enemy to start emitting fragments.
// As a special case, attacks with no defined priority (PRI_MISSING) can trigger
// anything -- this is the "priority" associated with attacks not governed by
// Gun Bonsai.
// It is currently stored in the `weaponspecial` field, on the assumption that
// this is not used for anything on projectiles.
// Possible other places if that turns out to be unsuitable:
// - movecount (used by monsters)
// - accuracy, stamina, health, or reactiontime
// - score
enum ::UpgradePriority {
  ::PRI_NULL = -1,   // Disallow cross-upgrade triggering at all
  ::PRI_MISSING = 0, // SPECIAL PURPOSE -- DO NOT USE
  ::PRI_ELEMENTAL,
  ::PRI_THORNS,
  ::PRI_EXPLOSIVE,
  ::PRI_FRAGMENTATION
}

class ::BaseUpgrade : Object play {
  uint level;
  bool enabled;

  // VIRTUAL FUNCTIONS //

  // Tick function. Equivalent to Thinker.Tick() but we define it here because
  // we can't inherit from Thinker and have the upgrades survive level changes.
  virtual void Tick(Actor owner) {}

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
  // CheckPriority is marked virtual so that upgrades doing weird things can
  // override it to perform more complicated checking logic; see the
  // ElementalBeam upgrade for an example of this.
  virtual ::UpgradePriority Priority() { return ::PRI_NULL; }
  virtual bool CheckPriority(Actor inflictor) {
    return !inflictor
      || inflictor.weaponspecial == ::PRI_MISSING
      || (inflictor.weaponspecial > Priority() && Priority() != ::PRI_NULL);
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

  // Called to activate upgrades that have permanent rather than event-driven
  // effects.
  // THIS FUNCTION MUST BE IDEMPOTENT. It may be called multiple times without
  // intervening calls to OnDeactivate(). Do not attempt to keep track of whether
  // the upgrade is "active" or not and decide whether to act based on that,
  // because it can also (e.g.) be activated, then moved to another weapon and
  // activated again with no intermediate OnDeactivate(), depending on the user's
  // settings.
  // On call, the PerPlayerStats will always be defined; the WeaponInfo will be
  // null unless the upgrade is associated with a weapon.
  // It is called:
  // - when the upgrade is first learned or leveled up
  // - when the upgrade is enabled via the status menu after having been disabled
  // - (player) when the PerPlayerStats are (re)associated with a PlayerPawn
  // - (weapon) when the corresponding weapon becomes selected
  virtual void OnActivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    DEBUG("OnActivate: %s", self.GetClassName());
  }

  // Called to deactivate upgrades; should undo whatever OnActivate did. Like
  // OnActivate, this should be idempotent.
  // It is called:
  // - when an upgrade is disabled via the status menu
  // - (weapon) when the corresponding weapon becomes deselected
  virtual void OnDeactivate(TFLV::PerPlayerStats stats, TFLV::WeaponInfo info) {
    DEBUG("OnDeactivate: %s", self.GetClassName());
  }

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

  virtual void OnKill(PlayerPawn pawn, Actor shot, Actor target) {
    return;
  }

  // Called to get the details tooltip when hovered over in the status or level-up
  // screen. Should report stats as if the upgrade were the given level.
  // Stats inserted into fields will be used to substitute the @1, @2, etc markers
  // in the upgrade's corresponding _FF LANGUAGE key.
  virtual void GetTooltipFields(Array<string> fields, uint level) const {}

  // Utility functions for GetTooltipFields
  // 0.25 -> 25%
  static string AsPercent(double mult) {
    return string.format("%d%%", mult * 100);
  }
  // 0.25 -> +25%
  static string AsPercentIncrease(double mult) { return "+"..AsPercent(mult); }
  // 0.25 -> -75%, e.g. all damage taken x0.25 is a 75% damage reduction
  static string AsPercentDecrease(double mult) {
    return string.format("-%d%%", (1.0 - mult) * 100);
  }

  // INTERNAL DETAILS //
  string GetName() const {
    return StringTable.Localize("$"..self.GetClassName().."_Name");
  }

  string GetDesc() const {
    return StringTable.Localize("$"..self.GetClassName().."_Desc");
  }

  string GetTooltip(uint level) const {
    Array<string> fields;
    GetTooltipFields(fields, level);
    let format = GetTooltipFormat();
    if (!format) return "";
    for (uint i = 0; i < fields.size(); ++i) {
      format.Substitute("@"..(i+1), fields[i]);
    }
    return format;
  }

  static string FieldDiff(string from, string to) {
    if (from == to) return from;
    return string.format("(\c[RED]%s\c- -> \c[GREEN]%s\c-)", from, to);
  }

  string GetTooltipDiff(uint lv1, uint lv2) const {
    Array<string> fields1, fields2;
    GetTooltipFields(fields1, lv1);
    GetTooltipFields(fields2, lv2);
    let format = GetTooltipFormat();
    if (!format) return "";
    for (uint i = 0; i < fields1.size(); ++i) {
      format.Substitute("@"..(i+1), FieldDiff(fields1[i], fields2[i]));
    }
    return format;
  }

  string GetTooltipFormat(uint n=0) const {
    let key = self.GetClassName().."_TT";
    if (n) key = key..n;
    let tt = StringTable.Localize("$"..key);
    return (tt == key && !n) ? "" : tt;
  }
}

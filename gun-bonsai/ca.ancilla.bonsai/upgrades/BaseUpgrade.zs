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
// - Optionally, add a tooltip with more details, in [upgrade_class_name]_TT; if
//   you want to add dynamic details, put @field-name markers in the tooltip and
//   populate them in GetTooltipFields() in your upgrade.
// - Add a BONSAIRC lump to your mod with a Register directive for your upgrade(s).
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
  uint level; // Upgrade's current effective level
  uint max_level; // Max level the upgrade can be set to
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

  // TODO: Investigate if we can do something useful with WorldHitscan(Pre)Fired
  // and WorldRailgun(Pre)Fired here -- that might make it possible to trigger
  // things like Explosive Shots even when they hit terrain! Might also break
  // LZDoom compatibility, though.

  // Called when the player is about to damage something. Should return the actual
  // amount of damage to deal; this will be converted to int once all ModifyDamage
  // handlers have run.
  // Note that you can't add projectile flags here and have them do anything --
  // to modify projectiles in flight use OnProjectileCreated, and to add on-hit
  // effects (which, for hitscans, is the only way to add effects at all), use
  // OnDamageDealt.
  virtual double ModifyDamageDealt(Actor pawn, Actor shot, Actor target, double damage, Name attacktype) {
    return damage;
  }

  // As ModifyDamageDealt but called when something else is about to damage the
  // player.
  virtual double ModifyDamageReceived(Actor pawn, Actor shot, Actor attacker, double damage, Name attacktype) {
    return damage;
  }

  // Called *after* the player damages something. This can be used to apply on-hit
  // effects. The amount of damage passed in is the actual damage dealt, after any
  // ModifyDamage calls have taken effect. Can also be used to check for kills by
  // checking the target's hp.
  virtual void OnDamageDealt(Actor pawn, Actor shot, Actor target, int damage) {
    return;
  }

  // As OnDamageDealt but called after something damages the player.
  virtual void OnDamageReceived(Actor pawn, Actor shot, Actor target, int damage) {
    return;
  }

  // Called when the player kills something. This won't be called for all deaths,
  // only those where the player is attributed as the killer. Note that this does
  // not obey normal upgrade-trigger priority rules -- it is always called and it
  // is the upgrade's responsibility to avoid unwanted recursion.
  virtual void OnKill(PlayerPawn pawn, Actor shot, Actor target) {
    return;
  }

  // Called when the player picks up an item. This does not reliably detect items
  // that merge with other things in the player's inventory, and may be called
  // multiple times, and/or on items that can be picked up in principle but not
  // right now (e.g. medkits when the player is at full health).
  // At the moment it's only used by upgrades that care about max armour to figure
  // out what your "max armour" actually is, and it's safe to use in that role,
  // but carefully consult the comments in PerPlayerStatsProxy.HandlePickup for
  // caveats if you want to use it for anything else.
  virtual void OnPickup(PlayerPawn pawn, Inventory item) {
    return;
  }

  // Called to get the details tooltip when hovered over in the status or level-up
  // screen. Should report stats as if the upgrade were the given level.
  // Stats inserted into fields will be used to substitute the @1, @2, etc markers
  // in the upgrade's corresponding _FF LANGUAGE key.
  virtual void GetTooltipFields(Dictionary fields, uint level) const {}

  // Utility functions for GetTooltipFields //

  // 0.25 -> 25%
  static string AsPercent(double mult) {
    return string.format("%d%%", mult * 100);
  }
  // 1.25 -> +25%
  static string AsPercentIncrease(double mult) { return "+"..AsPercent(mult - 1.0); }
  // 0.25 -> -75%, e.g. all damage taken x0.25 is a 75% damage reduction
  static string AsPercentDecrease(double mult) {
    return string.format("-%d%%", (1.0 - mult) * 100);
  }
  // 64 -> 2m; 80 -> 2.5m
  static string AsMeters(uint u) {
    if (u % 32 == 0) {
      return string.format(StringTable.Localize("$TFLV_TT_METERS_INT"), u/32);
    } else {
      return string.format(StringTable.Localize("$TFLV_TT_METERS_REAL"), u/32.0);
    }
  }

  // 28 -> 0.8s; 70 -> 2s
  static string AsSeconds(uint tics) {
    if (tics % 35 == 0) {
      return string.format(StringTable.Localize("$TFLV_TT_SECONDS_INT"), tics/35);
    } else {
      return string.format(StringTable.Localize("$TFLV_TT_SECONDS_REAL"), tics/35.0);
    }
  }

  // (1,3) -> 1-3
  static string AsRange(uint low, uint high) {
    return string.format("%d-%d", low, high);
  }

  // INTERNAL DETAILS //
  string GetName() const {
    return StringTable.Localize("$"..self.GetClassName().."_Name");
  }

  string GetDesc() const {
    return StringTable.Localize("$"..self.GetClassName().."_Desc");
  }

  string GetTooltip(uint level) const {
    let fields = Dictionary.Create();
    GetTooltipFields(fields, level);
    let format = GetTooltipFormat();
    if (!format) return "";
    for (let i = DictionaryIterator.Create(fields); i.Next();) {
      format.Substitute("@"..i.Key(), i.Value());
    }
    return format;
  }

  static string FieldDiff(string from, string to) {
    if (from == to) return from;
    return string.format("(\c[RED]%s\c- -> \c[GREEN]%s\c-)", from, to);
  }

  string GetTooltipDiff(uint lv1, uint lv2) const {
    // Levels must be at least 1, since level 0 upgrades definitionally do nothing.
    lv1 = max(lv1, 1);
    lv2 = max(lv2, 1);
    let fields1 = Dictionary.Create();
    let fields2 = Dictionary.Create();
    GetTooltipFields(fields1, lv1);
    GetTooltipFields(fields2, lv2);
    let format = GetTooltipFormat();
    if (!format) return "";
    for (let i = DictionaryIterator.Create(fields1); i.Next();) {
      format.Substitute("@"..i.Key(), FieldDiff(i.Value(), fields2.At(i.Key())));
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

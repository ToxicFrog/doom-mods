# Weapon Tracking and Weapon Logic

This document describes the intended design for weapon handling, hopefully to be
deployed in 0.9.0.

## Weapon Tracking

We replace the current set of weapon typenames in the Regions with a set of
actual `Weapon` references. In global weapon mode we simply populate all of these
with the same weapons from the RandoState. In per-level weapon mode we populate
only the one for the current map.

On reconcilation, we sweep the player's inventory, deleting all Weapons that do
not appear in that table, and inserting all Weapons that appear in the table but
not in the player's inventory. This does mean that on game load we may end up in
a state where weapons are duplicated between between the RS and the player, but
this is probably fine, the player-side ones will get discarded and replaced.

This does require that at runtime the state be aware of whether we are running
in per-level or game-wide mode. Open question: can we make this more elegant
such that it works the same in either mode?

## Weapon Granting

In per-level mode, we reify the weapon grants as GZAP_Weapon_$TYPE_$MAP classes,
with Default parameters naming the weapon and map, similar to how level access
tokens are currently handled.

Option one: when granted one of these, we run over to the corresponding Region
and record the granted weapon RandoItems in its granted-weapon set. On entering
the level or otherwise triggering reconcilation, we dispense any weapons listed
there where num_vended < num_received.

Option two: we don't have a separate data structure for this at all. We just
sweep the AP inventory and look for all RandoItems that are subtypes of GZAP_WeaponToken
where the Map is the enclosing region and there are still some un-vended.

So, the game flow looks something like this:
- when receiving a weapon, just put it in the item table
- when entering a level, or if we just received a weapon for the current level,
  trigger reconcilation:
  - remove all weapons not in the weaponlist
  - add all weapons in the weaponlist but not in inventory
  - spawn all not-yet-granted weapons
- after spawning a weapon, update the weaponlist for that map

For game-wide mode...the main differences are:
- the weaponlist is the same across all maps
- we trigger reconcilation upon receiving a weapon regardless of what map we're in

Maybe we put these behaviour differences in the tokens? If we are doing per-map
stuff, we have per-map tokens, GetDefaultByType() returns something that knows
about both the weapon and the map, we call OnGrant() on it and it bumps the txn
on that region and marks the apstate dirty if that is the current region.

If we're not, we have game-wide tokens, GetDefaultByType() returns something
that doesn't know about maps, OnGrant() marks the apstate unconditionally dirty.

### For later investigation

We can make a common superclass for all of these AP-inventory tokens with a
on-granted handler that subclasses can override, thus doing away with the
special handling in RandoState.GrantItem (which is currently only used for
txn bumps but promises to get much more complicated very quickly as we implement
per-level weapon tracking). (Or does it?)

## Weapon Logic

For any given reachable, we define two sets of weapons, *needed* and *wanted*.
*Needed* weapons are defined solely through the region mechanism. *Wanted*
weapons can be defined in regions, or can be inferred from the weapons available
in the level or in earlier levels.

*Needed* weapons are hard requirements.

*Wanted* weapons are trickier. The "require a percentage of these weapons" setting
in current versions doesn't actually work that great.

My inclination is to have a bunch of individual toggles here:
- weapon logic enable (if set wanted weapons are required, if not they are ignored)
- weapon logic populate from same map (weapons in the enclosing level are considered wanted)
- weapon logic populate from preceding maps (weapons in the preceding levels are considered wanted)
- weapon logic include secrets (if unset weapons marked secret are not counted)

We could be smarter about this if the scanner included weapon data (e.g. an AP-WEAPON
record every time the scanner finds a new weapon type). For starters, that would
let us check a bunch of flags that maybe indicate this weapon should be handled
differently: +MELEE and +WIMPY mean that maybe we shouldn't consider it at all
(unless it's a melee-focused mapset), +NO_AUTO_SWITCH, +NOAUTOSWITCHTO, and
+NOAUTOFIRE to indicate that the weapon is, perhaps, dangerous to use. In the
upcoming release there's also +BFG for "weapon is exceptionally powerful" and
+EXPLOSIVE for "weapon is potentially self-damaging".

We could also read the ammo data for the weapon so that we can be smarter about
logic; a weapon doesn't count as available in weapon logic unless you have the
weapon *and* a sufficiency of ammo for it (if ammo is randomized). This also
means that we can make smarter decisions about which guns are expected to be
used by the player in which maps by looking at *what ammo is in that map*.

More thoughts about weapon logic -- having regions lets us be more rigorous
about this.

So if you turn on local weapon logic, each region has added to its prerequisites
all weapons that exist inside it. This also makes them prerequisites of all
regions downstream of that one! But that doesn't work for leaf nodes, e.g. if a
region is Big Arena and has guns in Big Arena North Closet, Big Arena isn't
considered to have those guns. Hmm.

/want weapon markers work around this, although it does mean weapons from leaf
secrets won't be collected when secrets are enabled.

If you turn on global weapon logic, each level has added to its prerequisites
all weapons that exist in earlier levels. (Ideally we should have something
smarter than rank for this; E1M3 shouldn't depend on E4M2's weapons).
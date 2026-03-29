# Weapon Tracking and Weapon Logic

This document describes the intended design for weapon handling, hopefully to be
deployed in 0.9.0.

## Weapon tracking

The core idea is that of a *weapon capability* or wcap. This is associated with
a weapon and a scope (probably either a single map or the entire game) and grants
you use of that weapon within that scope.

Conceptually, this is easy and lets us handle them like keys: whenever we do a
weapon update (e.g. on level entry or when receiving a new wcap), we:
- remove all weapons from the player's inventory;
- add to the player's inventory all weapons they have valid wcaps for.

Unfortunately, there are complications.

The first is starting inventory. In a typical game of Doom the scanner never
sees the fists or pistol, they just manifest in the player's inventory on game
start. A naiive implementation of the above would revoke those weapons when
doing a weapon update.

The other problem is replacers. Take, for example, Traiblazer, which may replace
the rocket launcher with either the grenade launcher or the revolver at random.
This means that every time we do a weapon update, we'll think that the player is
missing the rocket launcher, take away the GL or revolver, and give them a new
one, which may interrupt their attacks or randomly flop them between weapons.

So, we need a way to turn *speculative* weapon capabilities into *actual* weapon
capabilities.

We define a new type for storing speculative wcaps (s-wcaps) and actual wcaps
(a-wcaps), and create a set for each, initially empty. These are stored per
region.

Every weapon AP knows about is turned into a *weapon grant* type, parameterized
by scope and by weapon typename. Upon receiving a weapon grant, we immediately
mark it as dispensed, and create an s-wcap for it -- in its corresponding region
if scoped, in every region if not. The s-wcap is marked *pending*.

When doing a weapon update, we:
- remove all weapons the player is carrying but does not have a-wcaps for
- add all weapons the player has a-wcaps for but is not carrying
  - we can probably do this directly (`A_GiveInventory`) since we know a-wcaps will not be further replaced
  - we may be able to store an actual Weapon actor in the wcap, not just a typename
- for each pending s-wcap:
  - spawn the corresponding weapon
  - mark the wcap as completed
- when the player picks up a weapon (via the pickup detector), create an s-wcap for it
  - we will need a global flag for whether weapon grants are scoped
  - if they are, the new caps are scoped to the current level
  - if not, they are scoped to the entire game, and replicated to all regions

### Native starting inventory

To handle starting inventory (e.g. pistol and fists) properly, we introduce the
conception of an *initial weapon update*. To do this, we simply wait for the
player to finish spawning in and then infer new a-wcaps for every weapon in
their inventory, scoped to the entire game. We do not initialize IPC until
*after* doing this, as otherwise it might get mixed up with weapons granted in
the initial communication with AP.

### AP starting inventory

This happens in `OnRegister`, so it will definitely be complete by the time we
load into a map. If these are actual weapon grants, they will be handled
normally by the machinery above. However, it is possible for the starting
inventory to include items AP doesn't know about but the engine does, which
means it can contain an actual `Weapon`.

In that case -- or whenever we receive a `Weapon` rather than a weapon grant
from AP in general -- we immediately mark it dispensed, as if it were a grant,
and invent an s-wcap for it containing the named weapon type and with a scope
of the entire game.

### Out-of-band weapons

If the player has weapon suppression set to 2 or 3 this is a non-issue. On lower
levels they may pick up weapons outside the weapon capabilities system that they
will want to keep.

I think the proposed design above handles this automatically -- if they are
permitted to pick up the weapon in the first place, the pickup detector will
automatically create either a global or map-scoped capability for them.

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

## Weapon Suppression

The basic idea of weapon suppression is: prevent the player from picking up
weapons that they haven't unlocked through Archipelago.

Doing this is, in the general case, hard, because when a weapon spawns it could
set off an arbitrarily complicated chain of replacements using `X replaces Y`,
`CheckReplacement`, `SpawnItemEx`, etc, and when the player touches it it can
also use things like `GiveInventory`. So we don't try to deal with any of that!

Instead, in `CheckReplacement`, we encase the weapon in an AP token before it can
be replaced with anything. When the player touches it, we then take action based
on the weapon suppression configuration, either rejecting the interaction
entirely, or deleting the token and spawning the original weapon or ammo for it
in its place.

Making that decision can be tricky, because in two of the operating modes it
needs to decide based on what weapons the player is carrying, looking for either
a matching weapon or a weapon of the same slot. We have a choice here of using
the player's inventory, the AP inventory, or both.

The slot check is actually comparatively safe; we get the slot of the encased
weapon, iterate the weapon slot data, and see if any of the weapons using that
slot are represented in either the AP inventory or the player's inventory.

For the identical weapon check, similarly, we can just walk the AP inventory
and/or player inventory, but this gets trickier when replacements are in effect
during the scan. Consider Time Tripper:

- the *map data* contains a `Chaingun`
- the *DECORATE* defines `class 64Chaingun : Chaingun replaces Chaingun`
- the scanner sees `64Chaingun`
- at runtime, `CheckReplacement` sees a `Chaingun`, which doesn't match the
  contents of the AP or player inventory

To handle that, we check for both the original weapon and the current
replacement. This should handle pretty much every case except the case where one
set of replacements was in effect during the scan, and a *different* set is in
effect at runtime, e.g. if you were playing Time Tripper with Rust'n'Bones
loaded or something.

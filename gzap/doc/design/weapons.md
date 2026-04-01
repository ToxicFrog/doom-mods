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

So, we need a way to turn *speculative* weapon capabilities into *real* weapon
capabilities.

We define a new type for storing speculative wcaps (s-wcaps) and real wcaps
(r-wcaps), and create a set for each, initially empty. These are stored per
region.

Every weapon AP knows about is turned into a *weapon grant* type, parameterized
by scope and by weapon typename. Upon receiving a weapon grant, we immediately
mark it as dispensed, and create an s-wcap for it -- in its corresponding region
if scoped, in every region if not. The s-wcap is marked *pending*.

When doing a weapon update, we:
- remove all weapons the player is carrying but does not have r-wcaps for
- add all weapons the player has r-wcaps for but is not carrying
  - we can probably do this directly (`A_GiveInventory`) since we know r-wcaps will not be further replaced
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
player to finish spawning in and then infer new r-wcaps for every weapon in
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

### Local vs. global capabilities

The easiest way to implement this is only to have local wcaps, and granting the
player a global wcap actually grants them a local one on all maps. However, this
causes some UX weirdness; in particular, if replacers are involved, we get
situations like:

- player is given a SuperShotgun globally
  - this is converted into a pending SuperShotgun wcap on each map
- in the current map this turns into a ChromeJustice
  - this produces a real wcap *for this map only* for ChromeJustice
- the player changes maps
- they don't have a real wcap for ChromeJustice so it gets revoked
- the pending wcap for SuperShotgun turns into an Eliminator this time
- now the player has been given a global SuperShotgun cap, but on MAP01 that
  means a ChromeJustice and on MAP02 it means an Eliminator

This isn't awful, but ideally I'd like that to only happen when per-level scopes
are enabled in the config. And do this we need a distinction between global and
local caps, which we accomplish simply by defining a special global scope named
`*`.

When playing without per-level scopes, this is easy. We set the all_caps_global
bit in the wcaps structure, any capability that gets added is automatically a
global cap when this is set (`scope` is always treated as `*` no matter what the
caller asked for). This applies to both pending and real caps.

When playing with, it gets trickier, because need to concern ourselves with:
- starting inventory (this is handled with `AddGlobalRealCap()` which does the
  right thing)
- weapon grants from AP (these are handled normally)
- starting weapon grants from AP (handled as above)
- starting raw weapons from AP (hmm)

The last one is the trickiest and, in particular, shows up in Time Tripper, where
our forced starting inventory is `Shotgun2` (which AP knows about and can turn
into a weapon grant) and `64Chainsaw` (which AP does *not* know about and must
spawn blindly using `GrantItemByName`). Both of these should be global weapon
capabilities even if per-level weapons are on!

So. I think, on the generator side, we stop understanding "naked" weapons at all
-- all weapons in the logic file manifest as weapon *grants*, scoped or
unscoped.

If the player asks for weapon *grants* in their starting inventory, this is
handled normally, and the grants are either scoped or unscoped depending on what
the player asked for. (This does mean we need an AP name for global weapon
grants that doesn't overlap with the plain typename. `Shotgun (MAP01)` vs.
`Shotgun (everywhere)` perhaps. Or `Universal Shotgun`.)

If the player asks for a *plain weapon*, this turns into a pending global wcap
if per-map caps are off, and is copied to all levels if per-map caps are on.

In the time tripper case, this means that:
- if per-map weapons are off, the starting `Shotgun2` and `64Chainsaw` turn into
  global pending wcaps, which vend, which produce weapons, which turn into global
  real wcaps
- if per-map weapons are on, the starting `Shotgun2` and `64Chainsaw` turn into
  per-map wcaps on every map, which turn into real wcaps on each map entry
and we're safe.

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

*Wanted* weapons are trickier. The "require a percentage of these weapons"
setting in current versions doesn't actually work that great. This describes the
proposed replacement.

### YAML settings

#### weapon_logic

- off: only `need` requirements from the tuning file are used
- manual: `need` and `want` requirements from the tuning file are used
- auto: as `manual` + automatic weapon logic per below

With `auto`, we automatically compute a set of desired weapons for each level
and the settings below control exactly what goes into it.

We could autopopulate by region, but I am optimistically assuming here that any
map that has regions defined also has weapon logic annotations.

#### auto_weapon_logic_pistol_start

On/off. In "pistol start" mode, only weapons present in a level will be
considered. Otherwise, weapons in preceding levels will be considered as well.

We might combine this with the above, so that it's `weapon_logic_mode` and the
options are off, manual, auto_per_level, and auto_per_episode.

#### auto_weapon_logic_secrets

On/off. If on, weapons in secrets will be considered. If off, they will not be.

#### auto_weapon_logic_difficulty

Threshold for adding weapons to the weapon set.

This is defined as a percentage of the most popular weapon. If set to 100, only
the most popular weapon (or weapons, if there is a tie) will be required. If set
to 0, any weapon the player could have access to will be. Intermediate values
set a cutoff based on the most popular weapon, so if have a weapon catalogue
like:

    1 chainsaw
    3 shotgun
    3 super shotgun
    1 chaingun
    2 rocket launcher
    1 plasma rifle

The most popular weapon is 3, so the breakpoints are 100 (gets you both
shotguns), 66 (also gets you the rocket launcher), and 33 (gets you everything).

TODO: do we want a hard threshold for "if this weapon appears more than this
many times we include it regardless"? Ideally I think we want it so that by the
end of the game every weapon is considered logically required.

### Implementation

For explicit weapon prerequisites, we just check the value of the option when
compiling them and if weapon logic is enabled, include all `want` prereqs.

For automatic ones, we move the current code into separate functions (so that
we can also use it to determine weapon categorization). The basic concept
(populate a desired weapon set based on weapons in this and/or previous levels)
is the same. Unlike the existing code, however, we use a Counter, so we can
keep track not just of which weapons but *how many*.

If auto weapon logic is off, this is empty.

If it's on, this is all weapons in the current level (in pistol start mode) or
the current and all preceding levels (in episodic mode), possibly including
secret weapons depending on settings.

Finally, we deterministically choose the actual weapons we expect based on the
difficulty.

If per-map weapons are off, we assume that all weapons are progression items
even if none of them are ever logically required.

If per-map weapons are on, when creating items, we query each map and see which
weapons are logically required, mark them as progression, and mark the rest as
useful.

### Future work

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

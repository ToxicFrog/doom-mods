# Nonlinear hubs

⚠️ This is a work in progress.

This document attempts to describe the desired behaviour when randomizing wads
based on around nonlinear, persistent hubclusters. *Faithless* is our model
organism for this, as it is -- extensive ACS scripting notwithstanding --
relatively straightforward while still exhibiting the highly interconnected
nonlinearity characteristic of these wads, but similar concerns apply to wads
like Hedon or Ashes Afterglow, where some "levels" are effectively multiple maps
joined together in persistent hubs with levelports.

Some of this may also be applicable to Golden Souls, although that has a more
hub-and-spoke design where visiting one spoke is *usually* not a prerequisite
for visiting another; only collecting enough keys is.

## Wad structure

Faithless is organized into three episodes. Each episode is a persistent
hubcluster containing 9-10 maps.

Maps are interconnected using a mix of ACS scripting and levelport linedefs.
Even the latter cannot be detected statically with complete reliably because
some of the linedefs are initially dormant, and only receive a levelport action
when a script is triggered.

The maps are connected in such a way that for any given map, you will often need
to travel to other maps and re-enter the original map from a new direction to
fully explore it.

Completion of an episode is signified by activation of a `75:teleport_endgame`
line special.

## Gameplay considerations

### Level access

There are a few ways we can treat level access in this sort of game, basically
breaking down along three axes.

**Per-episode vs. per-map.** Is each episode treated as a single giant level,
with a single access token, or does each map in the episode have a separate
access token?

**Shortcuts.** Is the player allowed to use the level select screen to warp to
individual maps in the episode, or does it only permit warping to the first map
of the episode?

**Strict vs. relaxed.** If you don't have the access token for a level, are you
allowed to access it via interlevel gates anyways?

The "safest" option is per-map, no shortcuts, strict. Per-map gives us more
spheres by completely excluding some items until we have the access token. No
shortcuts removes the very real possibility of levelporting to a part of the
level that isn't actually meant to be reachable until later, since the default
levelport destination doesn't necessarily match the intended route of reaching
the level. And strict prevents the player from going dramatically out of logic
and makes the access tokens actually meaningful rather than just a fast travel
network.

#### Better shortcuts

If we don't permit teleporting to a map until the first time the player has
reached it, and record where they appeared that time, we can use that as the
levelport destination when the map screen is used in the future.

If we're doing that anyways, we can also record the player's exact location when
they levelport *out* and return them there when they levelport back in.

### Victory conditions

Individual maps can't really be "finished", although episodes as a whole can be
via the `teleport_endgame` trigger. % of kills/checks/secrets VT conditions,
however, could still be done per-level once implemented. For the initial version
it is probably most straightforward to make the victory condition just "beat N
episodes". This effectively means generating `Exit` locations only for the final
map of each episode.

## Scanning considerations

Since we can't statically find exits, we need to either be told the list of maps
up front, or traverse all maps in a given cluster whether we can find exits to
them or not.

Rank logic is effectively meaningless here.

Key logic needs to be augmented with information about which levels the player
has reached so far. For example, map A may have some checks reachable from the
start, some checks that require the green key, and some checks that require
taking a path through map B (and which are thus unreachable if you don't have
access to map B).

Weapon logic is not meaningless, but we also can't assume that visiting a level
once results in having all the weapons it contained, nor that an entire level
shares a degree of weapon toughness (which is not true in plain Doom either,
but is a simplifying assumption we can generally get away with).

All of this effectively means that wads of this sort *require* pretuning to be
playable, and the pretuning needs to contain more information than it currently
does.

Since this all has implications for how logic and tuning data is interpreted,
we should emit an AP-SCAN message at the start of the logic file, with some
sort of indicator that this is logic for a hub-episode wad.

## Pretuning considerations

We need to know not just what keys a player has when collecting a check, but
also what weapons the player has and what maps they traversed to get here. To
that end, we introduce two new messages:

    AP-VISITED [list of maps]

Emitted the first time the player visits a new map. Contains the complete list
of maps the player has entered at least once. If shortcuts are off (or if
"improved shortcuts" is implemented) this is useful even outside of pretuning
mode, since it lets us map alternate but still valid routes -- e.g. locations in
map A that are normally only reached via map B, but can also be reached
directly if you get the green key early.

    AP-WEAPONS {map of weapon: count}

Emitted whenever the player receives a new weapon from AP. Contains all the
weapons the player has ever found. Doing this for every weapon and not just new
weapons means this is potentially useful for in-level weapon logic even for
traditional wads. This is likely only useful in pretuning mode, because outside
of it, players are highly incentivized to ignore weapon logic wherever they can.
That said, it might make sense to emit it unconditionally, in case it's useful
later, and just emit a pretuning marker in AP-XON.

At startup, the game should emit AP-VISITED and AP-WEAPONS messages so that the
apworld does not have to infer them.

## apworld behaviour

When loading the logic and tuning, we end up effectively ignoring weapon logic
at the map level. Instead we record key, weapon, and preceding-map information
in each Location we tune.

The access rule for each map is then "has access token", and the access rule for
each location in the map is "has listed set of keys and weapons and has access
to the listed maps".

It is tempting to hoist requirements common across each location in a map to the
map itself, e.g. if every location in a map requires the green key, say that
access to the map requires it. This has performance benefits when generating,
but it is also a trap, because it's possible that map A has locations that can
be reached via map B without the key, but you still need the key to reach any
location in B itself. So the actual hoisting needed is "requirement exists for
every location in this level and every location that lists this level in its
prerequisite set".

## End-to-end walkthrough

Faithless is loaded up and scanned. The starting levels are set to E?M1, with
hub-based recursive traversal on. The scanner emits an AP-SCAN message passing
through flags from the GZAPRC indicating that this is a hub-episode wad, and
follows it with the normal AP-MAP, AP-ITEM, and AP-SECRET messages.

At this point the generated logic isn't really usable except for pretuning. The
default logic for it has to assume that to reach any item in a given episode,
you need all the keys in that episode and also to have access to every level in
it.

A pretuning game is generated and played through. In addition to AP-CHECK
messages, it also emits AP-VISITED whenever the set of visited maps changes and
AP-WEAPONS whenever a new weapon is fed to `GrantItem`.

The tuning is then loaded. AP-VISITED and AP-WEAPONS messages are processed by
the WadLogicLoader directly to keep track of the current level and weapon set,
and passed to `tune_location`, which records them in the location. This likely
entails generalizing location prerequisites from keysets/weaponsets to some
shared `LocationPrerequisite` type. At this point, the wad is ready for play.

# Future work

I feel like this is brushing against the edges of a more general set of changes
to the scanner, by decoupling "map" from "level" and generalizing location
prereqs. In this model, AP-VISITED applies to any multi-map hubcluster by
default and Faithless is effectively modeled as three levels made up of several
maps each. This won't work for Golden Souls but it is a sensible way to model
Ashes and Hedon.

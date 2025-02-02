# Archipelago gzDoom connector

Three phases: scan, generation, play.

In scan mode, we need to build the info the generator needs - the set of regions,
locations, and items. And we need to output this as something the generator can
load.

In generation mode, this is all implemented in python in the APWorld. It'll load
the output from the scanner and emit something that play mode can load.

The user interface probably looks like a scanner pk3, the connector program, and two
shell scripts, apgzd-scan and apgzd-play. Scan loads up the selected megaWAD
along with the scanner pk3, which causes zscript to run that loads and scans
all of the levels and emits the findings as log messages, which the script captures.

play takes as input the megawad, the pk3 emitted by randomizer generation, and
login information, and sets up the requisite connections and launches the game.

## Scan Mode

This is the spicy part. We need to generate a reachability graph for the loaded
megawad, ideally without any user intervention.

I've thought of a few possible algorithms:

- pessimistic. assume that nothing is reachable until you have the level unlock
  *and* all keys in the level. This means that initially only levels with no keys
  will be playable, which is fine for D1/2 but breaks on e.g. Going Down, resulting
  in a game that's unplayable in singleplayer and starts you out in BK until someone
  else finds keys in multiplayer.
  Probably we want to define a set of "starting levels" and start the player off
  not just with access to those levels, but all the keys for them as well (or
  mandate that the keys in those levels do not get shuffled).
- exemplar. require the player to play through the game and record what they do.
  finding an item assumes that any keys the player holds are required to get that
  item. items the player doesn't find at all are marked "hard to get" and disallowed
  from holding progression items. guarantees real-world reachability but requires
  a full playthrough to generate.
- smart. try to traverse the sector graph and figure out what is reachable with
  and without keys automatically. this requires handling a shitload of edge cases,
  such as:
  - height differences > stepheight mean you can go down but not up
  - unlocked doors are traversable
  - unlocked *elevators* are traversable with implications for height difference calculation
  - locked doors are traversable with the key
  - doors controlled by remote linedefs need to be matched up with them, which
    also requires parsing the action special and keyflags on the line, stored
    in .special, the ML_REPEAT_SPECIAL flag, and .locknum.
- smart-ish. like smart but only handle the simple cases: sector edges within
  stepheight, unlocked doors, maaaybe elevators. Then consider everything else
  unreachable without all the keys. This should give better results than pessimistic
  for most levels.

Oh shit, smart and smart-ish immediately fail for stuff like Underhalls:
- the red key requires a *jump* to reach, by leaving a high sector and hurtling
  over a low sector to land on a medium sector;
- the switch you need the red key to access is behind a set of bars, which means
  that the sector is adjacent to the switch and counts it as "reachable" even
  before you have the red key without a *lot* of postprocessing;
- the switch is recessed, so adjacency/reachability calculations for it will be
  harder than otherwise
We also can't assume all levels follow a blue-yellow-red order.

I wonder if a "progressive keys" option would help at all -- picking up a key
gives you an indeterminate key, and the first time you use it on a door that
requires a specific key it turns into that key. Prooobably not?

Possible mitigations:
- don't shuffle keys at all, they always appear in their intended places
- don't shuffle keys in starting levels, assume all items are reachable in those
  levels, use pessimistic mode for other levels

super cursed half-formed idea around not actually putting items in specific locations,
but just deciding in advance what order the player will find them in and whatever
item you find next is the next item in the list

probably we only want to support pessimistic and exemplar for now.

output is probably going to be a mapping of
  [level] -> {
    [item] -> { name, type, coordinates, is_progression, keys_needed }
    mapname, title, difficulty info metrics
  }
which the generator can then use to synthesize region definitions and whatnot.

TODO: AP supports an item tier between "filler" and "progression" called "useful".
Maybe we put stuff like armor and health here?

It also, I think, lets you say "this should be shuffled but only within the same game".
So maybe we do that for "small" items.

Problem with exemplar mode -- say we have a level with a hub structure, like
Tricks & Traps, where:
- north is open and contains the blue key
- west is blue locked and contains the yellow key
- east is yellow locked and contains the red key
- south is red locked and contains the exit
Everything in north will be considered open, and everything in west will be considered
blue-locked, which is fine. But everything in east will be consider BY-locked,
and the exit BYR-locked, which is overly pessimistic.

! each difficulty level needs a different JSON since actor spawns depend on
difficulty level! We need to bake this into the JSON and assert if there's a
mismatch at startup

## Generation Mode

We can re-use the "upload ROM" feature here by letting the player specify a
reachability file output by the scan phase when generating. However, this means
any settings we expose to the user at generation time have to be megawad-agnostic.

The output is then a PK3 that includes the necessary support scripts and the
generation data.

Initial design -- very quick and dirty. Each level is a single Region; each major
item¹ in the level is a single Location. "Starting levels" are always considered
in logic and the player starts with the access code for them and all keys contained
therein.

¹ major items are: keys, weapons, upgrades, powerups, tools, and maps. We may
want to exclude a few things from randomization that levels are often planned
around: ArtiFly, ArtiTorch, EnvironmentalSuit, Infrared, and RadSuit. Alternately,
add them to the INVBAR and to the logic requirements (and remove inventory limits on them).

For everything else, the region is not considered "in logic" until the player
has the access code, all keys, AND all non-secret weapons in the level.

Once region construction is complete, we then fill the item pool thusly:
- access codes for all non-starting levels;
- one of each weapon except the pistol and fists, which the player start with;
- one of each key;
- one of each computer map (marked USEFUL), unless the player opted to start with all maps;
- all upgrades (marked USEFUL);
- powerups, tools, big-health, big-ammo, and big-armour, scaled in proportion to
  their original quantities to fill all remaining Locations.

All the locations these things are taken from are considered "in logic".

Probably want to rethink the scanner output to be item-first, rather than location-first,
since that lets me make decisions about e.g. which items and locations are considered
secrets more easily.

So, as we process item/monster entries, our behaviour looks something like this:
- if it's a new map, create a region for it
- if it's something flagged don't-randomize, skip it
- if it's randomize-in-level, add the item and location to a per-level *internal* pool,
  to be emitted in the final pk3. Probably separate pools for items/monsters, or
  maybe even subdivide pools more finely (small items vs. big, small/medium/big monsters).
- if it's randomize-in-game, as above, except the pool isn't per-level. It's still
  emitted into the final pk3.
- otherwise (randomize across worlds), add the item to the item pool and the
  location to the corresponding region.

For maximum generality, possibly what we actually want to do is always emit per-map pools.
Then at runtime we ask the server for our shuffle settings, and stuff marked don't-shuffle
we delete from the pools at startup, and stuff marked shuffle-gamewide we promote to a global
pool.

## Play Mode

Conceptually, this is straightforward. Load the seed info at startup. When
entering a level, replace items in it based on the seed info. When collecting
an item, transmit that information to AP. When someone else collects an item,
insert that into the player's inventory.

Doing this in practice is more difficult. The seed info can just be emitted by
the generator as a PK3, that's no problem. Outgoing communication is also easy --
gzdoom logs all console messages on stdout, so we can pipe it to a separate connector
program that scans for "picked up an item" messages, and generate such messages
on pickup.

Similarly, we can generate a level select menu on the fly, and incorporate access/
key/completion info into it.

For handling incoming events, I think we need to exploit the fact that if you
pass a directory to -file, the individual files in it are treated as lumps, and
that while they are only indexed on startup, ReadLump() will refresh the contents
from disk every time. So we start with an empty file, and the connector can write
state information into it, and gzdoom can periodically refresh it.

The *right* way to do this is to have the connector talk to gzdoom directly using
the networking protocol, and manifest itself as a do-nothing player (probably
using the NEVERTARGET flag or immediately self-destructing or both to minimize
interference). But that's a bigger project.

We also need to make sure that all levels are marked persistent (i.e. part of
the same nonzero "cluster"), either by generating a new ZMAPINFO or by setting
this at runtime using zscript, if possible, so that the player can leave a level
partway through and return to it later in the same state. (TODO: check if this
breaks things like the elevator door behaviour in GD. Maybe rig it so that you
return to your previous position rather than the level start?)
(Ok, it works with the GD elevators but maybe I still want "return to previous
position" by default, and perhaps a menu option for "return to level start" and
even, if I can manage it, "completely reset level".)

For maps, we can look at the Intuition power in GB to see how it works. There's
also the am_ family of cvars which let us display secrets, keys, etc if we want.

Monitor program is probably going to be written in Clojure, using the Java
bindings for APClient.

When receiving an item, we get the item ID, location ID it was found at, player ID
who found it, and the corresponding names via the DataPackage. So we need to turn
the ID (and/or name) into an item we can actually create in-game. This arrives via
a ReceiveItemEvent for each new item.

When sending an item, we call Client.checkLocation(id). So when touching an item
in-game we need to map it to the ID we used at generation item and check that.

When initializing the map, we can "scout" the locations (with Client.scoutLocations())
which will tell us what items are there; we get a series of LocationInfo events,
containing NetworkItems, same as ReceiveItemEvent -- each one contains IDs for item,
location, and player, corresponding strings, and a flag word with PROGRESSION,
USEFUL, and TRAP flags.

I think we don't actually *need* to scout; we can just display a generic item in
all the locations and send a check message when we hit it. But it's nice to be
more informative for the user.

I was planning to write the client in clojure, but since AP has a python connection
client built in (CommonClient) and clients for many games are built into AP itself,
so maybe it makes more sense to do that.

For big item randomization, we use CheckReplacement() to replace each big item
with an Archipelago location placeholder; once the placeholder initializes it
knows where it is and thus what its ID is, and can issue a scout request.

For small item randomization, we probably just bake the small item proportions
into the pk3 and swap them out in CheckReplacement().

More CheckReplacement thoughts.

At runtime, we know which actor categories are leave-alone, shuffle-level, shuffle-game,
and shuffle-multiworld. Assuming we can identify this entirely by class and not by
instance -- which should be possible -- we can then implement everything in
CheckReplacement().

Stuff that's leave-alone we just return.

Stuff that's shuf-multi, we replace with a MultiworldItemSpawner. On init it uses
its position to look up its locid in the position-to-Location table burned into
the pk3, then scouts that locid via the AP API to figure which icon to display
(minor, major, progression).

Stuff that's shuf-level or shuf-game, we replace with a RandomItemSpawner. It does
the same thing except instead of looking up the locid it looks up the replacement
pool for the given location category and draws something from the pool to replace
it. It then needs to remember what it drew, even across save/load, so that it can
produce the same results.

Problem: the CheckReplacement will fire for e.g. items dropped when enemies are
killed as well, and we need to do not do anything when that happens -- maybe
we can disable CheckReplacement one tic after level load?

Alternately, we do nothing in CheckReplacement, and in OnLevelLoad we instead
walk all thinkers and replace them. That's less efficient but might actually
work better.

If we continue to output scan messages during play, we can actually refine the
connectivity graph! We append the output to the earlier scan, and when processing
the event log, every CHECK event that is missing a key results in the location
definition being updated to exclude the keys that it's missing. This does struggle
a bit with or-effects, but maybe it's something like:
- if we check it with no keys, it doesn't need keys
- if we check it with keys and there is a minimal subset of keys, those are the keys
- if there are multiple distinct sets of keys none of which is a subset of the other,
  it's any of those subsets
the algorithm for this is actually pretty straightforward
let Km be the set of the keys in the map
initialize the key requirements Kl for each location to Kl={Km}
when the location is checked:
- if the player has no keys, Kl={}
- otherwise, add the set of player keys Kp to Kl, then remove from Kl all keysets k
  such that k is a proper superset of Kp

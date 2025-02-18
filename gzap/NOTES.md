# Archipelago gzDoom connector

## Scanner UI notes

Scanner menu is a list of all maps. Scanned maps show count of locations (+ excluded),
items, monsters, and bits for "include in output" and "include in rando". Unscanned
maps just show information about what wad they're from.

Selecting a map gives you more detailed information, and options to:
- go to this map and scan it
- go to this map and scan it and all later maps
- mark map exclude-from-rando
- mark map exclude-from-output
- start a tuning run on this map
- discard tuning data
- enqueue map for scan! you should be able to enqueue a bunch of maps and then
  scan them all at once.

Bottom of list includes a total and an "output logic file" command. The latter
checks if you have a logfile set and aborts if not.

## Compatibility issues

GDT MAP12 -- there are two red keys, one gets flushed when you enter the map,
the other appears later. They're meant to look like the same key, ofc. But it
means you can't ever collect the first one.

There's also a check (originally a shotgun) in a blueroom to the west; it's
not clear to me that there's any way to get this to spawn into the level.

We need some way of marking checks as uncollectable during tuning.

## client issues discovered in testing

- client leaves a background thread running on exit that continues to cause problems
  - may be an issue with how it's launched via multiprocessing rather than an issue with the client itself

## Item/location management for multiwad impl

Top-level DoomLogic holds the master item/location tables. These are map from name
to DoomItem/DoomLocation, I think.

When a wad is being populated, it unpacks the json into a DI/DL and then passes
it to the DoomLogic, which returns an ID, and then it maintains an internal map
of ID to count.

The DoomLogic does this by seeing if it already has a duplicate. If it doesn't,
this is easy, it generates a name, allocates a new id for it, stores it by name
and returns the id.

If it does have a duplicate -- well, what is a duplicate?
- unscoped items are duplicates if they have the same typename and tag
- scoped items are duplicates if they have the same typename, tag, and mapname

Setting aside locations for the moment because they're more complicated.

So, when we get a new item we generate a canonical name for it based on the tag
(+map if scoped) and then see if we have an existing item with the same name. If
we do, but it's not a duplicate -- which in practice means same tag, same map,
different type -- we mark both the old and new items as need_disambiguation, append the ID
to the name of this one, and insert it into the index.

Once we're done processing *all* imports of *all* logic records, we build the
real name to info map. For most things this is just existing name to existing info,
but for stuff with need_disambiguation, we instead render it is:

    "${tag} [${type}]" - unscoped
    "${tag} [${type}] (${map})" - scoped

E.g. "Red Keycard [RedKeycard] (MAP01)" vs. "Red Keycard [CustomModdedKeycard] (MAP01)"

So much for items. How do we handle locations?

This is more complicated because as far as AP is concerned, if two things have the
same name they're the same location. So "MAP01 - Shotgun" is the same location
whether it's referring to the one in Doom 2 or the one in Greytall. And it doesn't
care if, when generating the output mod, we map each one to a different set of coordinates
depending on what wad the player is generating for.

But it does mean we need to keep track of the different coordinates (for output generation)
and different keysets (for reachability modeling) of different versions of the same
location.

I could see a use case for doing this in wads as well -- we don't need separate
versions of RedKeycard and CustomModdedKeycard in the item table if there is no wad
that uses both, after all. (But, that complicates item handling considerably, so maybe
let's not.)

So maybe what we actually want to do is, the DoomLocation structures are stored
in the DoomWad itself, and the DoomLogic just stores a map of name to {id, needs_disambig}?
Then at generation time we just ask the selected wad for its locations.

And location names need be disambiguated only if the same location appears multiple
times in the same wad. Hmm.

So: we see a new location. If there's another location in the same wad with the same
coordinates, this is the same location and we just re-use it.

If there's another location in the same wad with the same name and different coordinates,
we get a new ID for it and mark both as needing disambiguation.

BUT, this means we can end up in a situation where:
- wad A has one shotty in the first level, "MAP01 - Shotgun"
- wad B has two! "MAP01 - Shotgun" is registered first and has the same ID
- then we see the second one and disambiguate, so we have
  "MAP01 - Shotgun [NW]" and "MAP01 - Shotgun [S]"
- but that means the second one's name has changed, so we need to break its association
  with the "MAP01 - Shotgun", a name we still want to keep for wad A
- then wad C comes along, registers two more shotguns and disambiguates them into
  "MAP01 - Shotgun [S]" and "MAP01 - Shotgun [N]" -- the former should reuse the
  same ID as the wad B version!

So let's try this again.

Top level just maintains a name-to-id map.

Individual wads maintain an id-to-location map and a position-to-location map.

When adding a location, if it shares a position with another loc in the same wad,
it's the same loc and we drop the duplicate.

If it shares a name with a loc in the top level, we re-use that loc's ID (but
enter our own definition for it).

If it shares a name with a loc in this wad, we mark both as needing disambiguation.

Then, during the disambiguation pass, foreach location being disambiguated:
- generate the new canonical name
- if it's already in the index, re-use that ID since it means another wad
  has already disambiguated and gotten the same name
- if it's not, generate a new ID for it and enter the new name and ID into the index

## Scan Mode

This is made to be very simple -- it just emits some map metadata + a list of
all items. The generator is where all the brains live, and handles combining this
with the refinement list (if any), associating locations with the keys of their
enclosing level, etc.

It's in the pk3 as a StaticEventHandler and is triggered by sending an "ap-scan"
netevent to the game after you enter the first level.

Since there are no stable location IDs or anything, locations are identified by
their coordinates + angle. :(

## Generation Mode

Need to handle the MAPINFO here.

Clustering for level persistence turns out to have some problems since there is
no way (in zscript) to reset just one level in a cluster, so let's leave that
alone for now.

Foreach map, we need to:
- remove `needclustertext`
- remove `entertext = ...` and `exittext = ...`
- remove `intro { ... }` and `outro = { ... }`
- add `allowrespawn`
- add `noclustertext`

## Play Mode

Static information baked into the pk3:
- mapping from integer APItem IDs to gzDoom class names for items
  + for level access tokens, we need to know what level it is
  + for keys, likewise
- mapping from coordinates to integer APLocation IDs
  + information about whether the location holds a progression, useful, or filler item
    we can get this from location.item.classification bitfield
- mapping from level names to integer APLocation IDs for the exits
- what items we start with
- how many locations each level contains

Information that needs to persist across levels at runtime:
- which keys we have (store it in a ::Keyring item in the player inventory?)
- which access/clear tokens we have (these can just go in inventory also)
- which locations we've checked (global, but since this matters per-level we may want to store it that way)

So, at startup, we do whatever data structure initialization we need, and then
do first-time startup: give the player an empty keyring, initialize the token/location
tracker to empty, then give the player their starting inventory.

Whenever the player gets a key (via AP), this should be added to the *keyring*,
which then optionally inserts it into the player's inventory.

On level entry (need an EventHandler for this), the keyring is told to update,
which it does by clearing all keys from the player's inventory, then checking if
it remembers any keys for the current level and inserting them.

Access tokens can be individual items, but it probably makes more sense to store
them, too, in the keyring. So now our keyring is taking shape:
  Map<mapname,Ring>
    Ring
      Array<Inventory> keys;
      Array<int> checked;
      bool access;
      bool cleared;



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

or maps, we can look at the Intuition power in GB to see how it works. There's
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

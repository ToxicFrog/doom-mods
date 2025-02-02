# GZAP Protocol

This file documents the three protocols used to communicate with the game:

- the *scan protocol* used when scanning a WAD;
- the *outbound event protocol* used to receive messages from the game;
- the *inbound event protocol* used to send messages to the game.

## Scan Protocol

These messages are put on the console and thus read by attaching a program to
the game's logfile or stdout.

All messages being with `AP-MSG`, where `MSG` is a string specific to the
message type.

### Position structures

Some messages include a `position` field. This is always an object of the form:

    position { x, y, z, angle, secret }

The coordinates are taken directly from the `pos` field in-game. `angle`,
likewise, is taken from the source actor. `secret` is taken from the enclosing
sector and may, someday, be used to exclude secrets from the critical path (or,
perhaps, require them) when randomizing.

### `AP-MAPINFO { map, title, secret, skill }`

Emitted when scanning of a map begins. `map` is the lump name (e.g. "MAP01"),
`title` is the user-facing title (e.g. "Entryway"). `secret` is true if the
scanner reached this level via a secret exit; if a level is accessible via both
secret and non-secret paths, it's undefined what value this has. `skill` is the
difficulty level the scan is being performed on, and is used for cross-checking
during play.

### `AP-ITEM { map, category, typename, tag, position }`

Emitted when an item is scanned. `map` is as above. `typename` is the gzdoom
class name (as returned by `GetClassName()`) and `tag` is the tag (as returned
by `GetTag()`).

`category` is an internal category used for item classification, and is finer-
grained than the (progression, useful, filler, trap) categories used by AP. The
full set of item categories is:

    key           keycards and puzzle items
    weapon        weapons and Hexen weapon pieces
    upgrade       backpacks
    map           automaps
    powerup       temporary powerups like blurspheres and berserk packs
    tool          items you can pick up and use later (including usable medkits)
    big-armor     armour suits and the megasphere
    small-armor   armour shards
    big-health    health that restores >50%
    small-health  other health
    big-ammo      ammo that restores more than 10% of max
    small-ammo    other ammo

### `AP-SCAN-DONE {}`

Emitted when all levels are done being scanned, so that the generator can do any
necessary preprocessing.


## Outbound Event Protocol

TBW, but early prototypes will probably be as above, just with different event
types -- at minimum we'll need `AP-CHECK`, but `AP-CHAT` and `AP-SCOUT` would be
nice too.

The production version will connect using the multiplayer protocol, send events
using EventHandler.SendNetworkCommand and EventHandler.NetworkCommandProcess.
The actual event names and payloads should be the same, though.


## Inbound Event Protocol

Also TBW. Early prototypes will use a file on-disk and rely on the fact that
ReadLump() re-reads the file contents from disk each time it's called. Production
version uses network commands as above. At minimum we need `AP-GETITEM`.

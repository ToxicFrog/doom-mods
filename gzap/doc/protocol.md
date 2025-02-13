# GZAP Protocol

This file documents the IPC protocol used to communicate between gzDoom and
Archipelago. It's used in two places:
- unidirectionally, when gzDoom produces a logic file that AP reads to prepare
  the randomizer;
- and bidirectionally, during actual play, for gzDoom to tell AP what checks
  you're finding and for AP to tell gzDoom what items you're receiving.

The outgoing (GZ->AP) and incoming (AP->GZ) sides use entirely different formats,
so they are documented separately.


## Outgoing Protocol

Outgoing messages are written to the game's log file. Each message is a single
line starting with `AP-$MSG `, where `$MSG` is the name of the message type, e.g.
`AP-MAP`. This is immediately followed by a JSON object containing the message
body. The body is not optional; empty messages must send `{}`.

Individual message types are documented below.


### Scan Messages

These messages are emitted during the scan process.

#### `AP-MAP { map, info: { ... } }`

Emitted when the scanner has just begun processing a map. `map` is the name of the
lump being scanned, e.g. `E1M1` or `MAP01`. `info` is an object containing information
needed to (re)construct the `MAPINFO` entry. It's not documented here as I expect
it to change rapidly in use as I encounter more edge cases; the canonical form
of it is the [`Mapinfo` class](../apworld/gzdoom/WadInfo.py) in the apworld.

#### `AP-ITEM { map, category, typename, tag, position: { x, y, z, angle, secret } }`

Emitted for each item the scanner finds. Note that this is *everything*; the randomizer
makes decisions about which items to randomize and which not to.

Fields:
- `map`: the map lump name, as above
- `category`: a guess at the item category
- `typename`: the gzDoom class name
- `tag`: the gzDoom human-facing name (if none, duplicates `typename`)
- `position`: the (x,y,z,θ) position of the item, plus a flag indicating if its
  containing sector is marked secret or not. `angle` and `secret` are not currently
  used for anything.

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

#### `AP-SCAN-DONE { skill }`

Emitted at the end of the scan, when all levels have been processed. `skill` is
the numeric skill value, 0-indexed (i.e. 0 is ITYTD, 2 is HMP, and 4 is NM).

<!-- TODO: support multiskill scanning, annotating each map with the current skill
     and scanning each map once per skill level -->


### Play/Tuning Messages

These messages are emitted during gameplay. They are expected to be read in real
time by the client, but can also be saved in a log and later appended to an existing
logic file to improve the logic.

#### `AP-CHECK { id, name, keys, unreachable }`

Emitted when the player checks a location. `id` is the AP location ID, and `name`
is the name assigned to that location by the randomizer. `keys` is a list of keys
held by the player and is used only for logic tuning.

If `unreachable` is true, this means that location cannot be reached in normal
play and should be restricted in future runs of the randomizer.

#### `AP-EXCLUDE-MAPS { maps: [...] }`

<!-- TODO: implement map exclusion UI and map tuning UI -->

Marks the given maps as excluded from randomization. This is primarily useful for
WADs where the scanner incorrectly picks up some IWAD levels in addition to the
PWAD levels, or where some levels are used for cutscenes or level select hubs
rather than normal gameplay.

Note that only the most recent `AP-EXCLUDE-MAPS` message has any effect, so you
can emit `[]` to undo all exclusions.

#### `AP-CHAT { msg }`

Send a chat message to the rest of the Archipelago players.

#### `AP-XON { lump, size }`

Tells the client that it is ready to receive messages. `lump` is the name of the
lump it's using as the IPC connector, and `size` is the maximum message buffer
size that can be written to it.

#### `AP-ACK { id }`

Tells the client that we have read messages it sent up to the given `id`, and
it can overwrite them with new messages if needed.


## Incoming Protocol

The incoming protocol works by repeatedly rewriting a file on disk, the contents
of which are read by gzDoom using `wad.ReadLump()`.

This has two caveats. The first is that the file must be inside a directory which
is in turn passed to gzDoom using the `-file` flag. Passing the file directly will
cause it to be copied into memory at startup, and subsequent changes on disk will
be ignored.

The second is that the max size is fixed on startup. If the file is subsequently
extended past that size, the extra bytes will be ignored. So it needs to be
preallocated to some useful size *before* gzDoom starts up, and must not exceed
that size during play.

### On-the-wire format

The file contains zero or more messages, terminated by ETB characters (`\x17`).
Each message consists of multiple fields separated by US (`\x1F`). The first
field is always the message ID (as a decimal integer), and the second the message
type (as a string); subsequent fields depend on the message type.

### Receiver behaviour

On startup, gzDoom reads and discards the file contents to determine the size,
then sends an `AP-XON` message to indicate readiness.

Periodically, gzDoom reads the complete contents of the file, and splits on ETB.
The last split is discarded; if the final message was complete, it ends with ETB
and thus the last split is "", and if it was incomplete, this discards the incomplete
message.

It then processes each message by splitting it on US and parsing the message ID.
If this is <= the highest message ID it's seen before, it skips the message.

For messages with higher IDs, it processes them and updates its highest-seen-message
counter. Once all messages in the file are processed, it emits an `AP-ACK` message
reporting the highest processed message ID.

### Sender behaviour

On startup, the sender should wait until it sees an `AP-XON` message from the
receiver, indicating that it has loaded the IPC lump and is ready for messages.

The sender assigns a monotonically increasing ID to each message and writes them
to the file in ascending order until it has no room for more messages (or until
it has no more messages to write; in the former case it must buffer further
messages internally). It then listens for an outgoing `AP-ACK` message that matches
the ID of the most recently written message, at which point it truncates the file.

### Message types

#### `CHAT` `user` `message`

Displays a chat message from the named user.

#### `ITEM` `id`

Gives the player the item with the given `id`. The actual item-to-id mapping is
dependent on the wad logic used for randomization.

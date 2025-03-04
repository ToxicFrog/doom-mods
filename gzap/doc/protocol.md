# GZAP Protocol

This file documents the IPC protocol used to communicate between gzDoom and
Archipelago. It's used in two places:
- unidirectionally, when gzDoom produces a logic file that AP reads to prepare
  the randomizer;
- and bidirectionally, during actual play, for gzDoom to tell AP what checks
  you're finding and for AP to tell gzDoom what items you're receiving.

The outgoing (GZ->AP) and incoming (AP->GZ) sides use entirely different formats,
so they are documented separately.


## Overview

Communication takes place over two channels, *outgoing* (from gzdoom to AP) and
*incoming* (from AP to gzdoom). When doing the initial map scan, only the outgoing
channel is used, and is written to a file for later loading. In play, both channels
are used.


## Outgoing Protocol (gzDoom -> AP)

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
of it is the [`MAPINFO` class](../apworld/gzdoom/model/DoomMap.py) in the apworld.

#### `AP-ITEM { map, category, typename, tag, secret, skill, position: { x, y, z } }`

Emitted for each item the scanner finds. Note that this is *everything*; the randomizer
makes decisions about which items to randomize and which not to.

Fields:
- `map`: the map lump name, as above
- `category`: a guess at the item category
- `typename`: the gzDoom class name
- `tag`: the gzDoom human-facing name (if none, duplicates `typename`)
- `secret`: whether the item is located in a secret sector or not
- `skill`: a list of skill values (1-3) the item appears on; if omitted, it is available on all skills
- `position`: the (x,y,z) position of the item

`category` is an internal category used for item classification, and is finer-
grained than the (progression, useful, filler, trap) categories used by AP. The
full set of item categories is:

    key           keycards and puzzle items
    weapon        weapons and Hexen weapon pieces
    map           automaps
    powerup       temporary powerups like blurspheres and berserk packs
    tool          items you can pick up and use later (including usable medkits)
    big-armor     armour suits and the megasphere
    small-armor   armour shards
    big-health    health that restores >50%
    small-health  other health
    big-ammo      backpacks and rainbow mana
    medium-ammo   ammo that restores more than 20% of max, like cell packs
    small-ammo    other ammo

Currently only some of these are actually used by the generator, but they are all
emitted for potential future use.

#### `AP-SCAN-DONE {}`

Emitted at the end of the scan, when all levels have been processed. Signals to
the importer that it can do any postprocessing needed.


### Play/Tuning Messages

These messages are emitted during gameplay. They are expected to be read in real
time by the client, but can also be saved in a log and later appended to an existing
logic file to improve the logic.

#### `AP-XON { lump, size, nick, slot, seed, wad }`

Tells the client that it is ready to receive messages. `lump` is the name of the
lump it's using as the IPC connector, and `size` is the maximum message buffer
size that can be written to it.

`nick` is the player's in-game name, used to extract chat messages from the log
(as a workaround for the difficulty in knowing when to emit `AP-CHAT` messages).

`slot` and `seed` are information about the generated game: the player's slot name
and the world seed string. The client uses these when establishing the connection
to the server.

`wad` is the name of the WAD as originally provided to the apworld (not whatever
gzDoom loaded from disk). This is used to name the generated tuning file.

#### `AP-ACK { id }`

Tells the client that we have read messages it sent up to the given `id`, and
it can overwrite them with new messages if needed.

#### `AP-CHECK { id, name, keys, unreachable }`

Emitted when the player checks a location. `id` is the AP location ID, and `name`
is the name assigned to that location by the randomizer. `keys` is a list of keys
held by the player and is used only for logic tuning.

`unreachable` means that the check is not reachable in normal play and the player
used cheats, forbidden techniques, or the `ap_scan_unreachable` command to collect
it; including that in the tuning file will prevent it from being used for progression
items in future games.

#### `AP-CHAT { msg }`

Send a chat message to the rest of the Archipelago players. Normally chat messages
are picked up directly from the log file, without involving this; however, some
mod features, like hinting, may generate chat messages in this manner.

#### `AP-STATUS { victory }`

Informs the client that the player is victorious (by setting `victory` to `true`).
This may be expanded with other uses in the future but for now it's just a way of
telling the client when the game is won.


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
field is always the message ID (as a decimal integer), and the second, the message
type (as a string); subsequent fields depend on the message type.

Note that ETB is a *terminator* while US is a *separator*, so a file containing
(e.g.) two `ITEM` messages will look like (whitespace for clarity):

    1 <US> ITEM <US> 7 <ETB> 2 <US> ITEM <US> 45 <ETB>

This also means that we can detect incomplete writes by checking if the last byte
read is ETB or not.

No mechanism for escaping is provided. We optimistically assume that no-one will
be sending chat messages with C0 control characters in them.

Messages are always written to the file in ascending ID order. The sender must not
write messages out of order, although skipping IDs is allowed.

### Receiver behaviour

On startup, gzDoom reads and discards the file contents to determine the size,
then sends an `AP-XON` message to indicate readiness.

Periodically, gzDoom reads the complete contents of the file. It splits on ETB
to break it into messages (and discards the last split, which is always either an
incomplete message or the empty string), then splits each message on US to get
individual fields.

It then skips messages until it sees one with an ID it hasn't previously acked,
and processes all remaining messages, dispatching based on the message type.

Once all messages in the buffer have been processed, it sends an `AP-ACK` message
reporting the highest processed message ID.

### Sender behaviour

On startup, the sender must wait until it sees an `AP-XON` message from the
receiver, indicating that it has loaded the IPC lump and is ready for messages.

The sender assigns a monotonically increasing ID to each message and writes them
to the file in ascending order until it has no room for more messages (or until
it has no more messages to write; in the former case it must buffer further
messages internally). IDs should be monotonically increasing *across process
executions* to be tolerant of client restarts; the reference implementation
uses `clock.monotonic()` for this purpose. The on-wire representation of the
ID can be any printable string as long as it later IDs sort after earlier ones.
(Why a string? Because then we don't need to worry about sending IDs that are
too large to fit into a zscript integer.)

On receiving an `AP-ACK`, the receiver should rewrite the file to discard any
messages with ID numbers <= the acked ID, and append any new messages it hadn't
previously had room for. Use of atomic writes is encouraged, as is truncating the
file to 0 bytes if all messages have been acked and none are pending.

If something needs to be written to the file other than valid message data for
some reasom, simply avoid ETB bytes; filling the entire file with null bytes or
with `.` works well.

### Message types

#### `TEXT` `message`

Displays a message from Archipelago. If it contains colour information it is the
responsibility of the *sender* to encode that; the colour escape character
represented as "\c" gzDoom string literals is "\x1C" (FILE SEPARATOR).

#### `ITEM` `id` `count`

Tells the game that they should have a total of `count` copies of item `id`,
before taking into account any used by the player.

If they already have that many, this is a no-op. If count is more than they have,
the game should update the total count, and increase the held amount to match.

The mapping from `id` to internal item type is determined by the randomizer and
baked into the generated mod.

#### `CHECKED` `id`

Tells the game that the location with the given ID has already been checked. The
game should remove it from the list of pending checks and (TODO) despawn it from
the world if it's currently spawned. It's safe for the player to re-collect it
but doing so won't do anything.

#### `HINT` `map` `item` `player` `location`

Tells the game that we have received a hint for the location of one of our items.
`map` is the map the item is scoped to (or the empty string if it's not a scoped
item). `item` is the item name without map qualification. `player` and `location`
are the name of the player who has it and the location in their world where it
can be found, potentially including colour codes.

For example, `HINT⋅MAP02⋅BlueCard⋅Link⋅Kokiri Shop` tells us that our
`BlueCard (MAP02)` can be found at the Kokiri Shop in Link's world, while
`HINT⋅⋅Shotgun⋅Link⋅Frog Concert` tells us that our `Shotgun` is at Link's
Frog Concert.

In-game, this is used to display the hints on the level select screen.

#### `PEEK` `map` `location` `player` `item`

Tells the game that we have received a hint for the contents of one of our locations.
`map` and `location` identify the location, `player` is the player whose item it
is (which may be us!) and `item` is the item name. Unlike `HINT`, none of these
fields can be empty. These are used by the level select screen to display information
about what's located where.

`PEEK⋅MAP01⋅Chainsaw⋅Link⋅Hookshot`, for example, indicates that the chainsaw on
"Entryway" contains Link's hookshot.

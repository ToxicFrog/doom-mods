# GZAP Protocol

This file documents the three protocols used to communicate with the game:

- the *scan protocol* used when scanning a WAD;
- the *outbound event protocol* used to receive messages from the game;
- the *inbound event protocol* used to send messages to the game.

## Scan Protocol

These messages are put on the console and thus read by attaching a program to
the game's logfile or stdout.

All messages begin with the text `AP SCAN ` followed by an EDN map, with some
subset of the following keys:

### `:map`

The lump name of the map (e.g. `"MAP01"`) as a string.

### `:info { :title :secret }`

Information about the map: its human-readable title (e.g. `"Entryway"`) and whether
it is a secret map or not.

### `:location { :x :y :z :angle :secret :item :monster }`

Information about an actor location. `:x :y :z :angle` contain positioning information
that (in most maps) will uniquely identify the location. `:secret` is true if the
location falls within a secret sector.

Exactly one of `:item` or `:monster` will be provided.

TODO: in exemplar mode, we need to include additional information about what keys
the player had when they touched the location.

#### `:item { :category :class :tag }`

Information about an item. `:category` is the scanner's best guess about the
item's category. It is more fine-grained than Archipelago's classification;
possible values are `:key`, `:weapon`, `:big-armor`, `:small-armor`, `:big-ammo`,
`:small-ammo`, `:big-health`, `:small-health`, `:powerup`, `:tool`, `:upgrade`,
or `:map`.

Most of these are self-explanatory. PuzzleItems count as keys. Tools are items
you can pick up and carry around for later use like health packs or Hexen artifacts.
Upgrades are non-progression items that give permanent upgrades like the backpack.

#### `:monster { :class :tag :boss :hp }`

Information about a monster. `:boss` is true if it's boss-flagged. `:hp` is just
its raw HP value and is used for very coarse difficulty estimation.

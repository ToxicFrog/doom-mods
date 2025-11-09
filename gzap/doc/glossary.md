# Glossary of Terms

It can get confusing wrangling stuff that is modeled in both the game and in the
randomizer but in different ways and for different purposes, so this file holds
the terminology I've settled on and try to keep the code in line with.

## Check

An *in-world* object associated with a *Location*. This is what the player actually
sees and touches in-game. It is mostly just a visible, collectable token, with the
actual randomizer state stored *out-of-world*.

## FQIN (Fully Qualified Item Name)
## FQLN (Fully Qualified Location Name)

The full user-facing Archipelago name of an item or location, including any
qualifiers for what map it's in. E.g. a "RedCard" could be any red keycard, but
the item with FQIN "RedCard (MAP02)" is specifically the red keycard for MAP02;
many maps have rocket launchers, and MAP07 may have more than one, but the FQLN
"MAP07 - RocketLauncher [W]" uniquely identifies the western rocket launcher
location in MAP07.

## Globbing Expression

A way of concisely writing a match for multiple maps (or items, filenames, etc...)
at once. In a glob, `*` matches anything, and `?` matches any one character. So:
- `E1M*` matches all maps in episode 1
- `E?M1` matches the first map of episodes 1-9 (but not E10M1, etc)
- `MAP?2` matches MAP02, MAP12, MAP22, etc
- `*` matches anything at all

These are supported by some of the YAML options to save you having to type out
dozens of individual maps.

## GZAP

Short for gzArchipelago, i.e. Archipelago for gzDoom. `GZAP_` is used as the
prefix for all gzArchipelago classes to avoid collisions with other mods.

## In-World

Objects that exist in the level somewhere, such as the player and *Check* actors.

## Item Categories

The scanner assigns one or more categories to each item (and its associated
location). These are used by the randomizer to make decisions about which items
to replace with checks and how to classify them in AP. Randomization can be
controlled on a per-category basis in the yaml.

Locations that originally contained items inherit the categories of their items.
Locations without items have categories assigned based on the nature of the
location.

In the logic file, categories are stored as hyphen-separated strings for
historical reasons, e.g. the category string "small-health" denotes an item
with both the `small` and `health` categories. A logic file can make up any
categories it wants and the apworld will automatically detect them, but the
current list of categories used by the wad scanner is:

- `key`: keycards, skulls, etc; specific to a single level or cluster
- `weapon`: any sort of weapon
- `powerup`: time-limited or per-level powerups (e.g. radsuits, berserk)
- `health`: anything that restores health
- `armor`: anything that restores armour
- `ammo`: anything that refills ammo
- `tool`: inventory items that aren't in any other category (e.g. time bombs)
- `token`: used internally by the apworld for things like access codes and level exits
- `big`, `medium`, `small`: used to differentiate different sizes of health,
  armour, and ammo pickups

In addition, there are some categories not present in the logic file but which
are used by the apworld:

- `ap_map`: Archipelago automaps (grant map view + check information).
- `ap_token`: Archipelago internal; do not use.
- `secret`: for items, means the item is located in a secret sector. For
  locations, means the location is checked by discovering a secret in-game.
- `sector`: `secret` locations only. Means the secret is a map sector.
- `marker`: `secret` locations only. Means the sector is an item or scripted trigger.

Some items will have multiple categories from this list, e.g. a Megasphere is
`big`, `health`, and `armor`, and also `secret` if it's found in a secret sector.

Health and armour is considered `big` if it restores 100 points or more, `small`
if it restores less than 25, and `medium` otherwise.

Ammo from Id games is considered `big` if it's a backpack, otherwise `medium` if
it's a larger ammo pickup and `small` otherwise. Unrecognized ammo (e.g. from
total conversions) is considered `medium` if it refills at least 20% of your
carrying capacity, and `small` otherwise.

## Level Rank

A measure of how far into the game a given level is. Any level you can reach from
the New Game screen is rank 0; levels you can reach from those are rank 1, etc.
The randomizer uses this for difficulty-based logic adjustments, based on the
theory that levels later in the game are probably harder than earlier levels.

For episode-based games like Doom 1 or Heretic, *every* start-of-episode level
is rank 0, so (e.g.) E1M1, E2M1, and E3M1 are all rank 0 and are all considered
"before" E1M2.

Since rank is based on what order you can reach the levels in when playing,
rather than what order they're listed in the WAD, the Doom 2 secret levels
MAP31 and MAP32 have ranks 15 and 16, in keeping with their position roughly
halfway through the game.

## Location

The *out-of-world* data about a location where a randomized item can be placed.
Contains information about how to display it, how to locate the actor to replace
in the world, and how to report its collection to Archipelago.

## Location Category

See *Item Category*.

## Out-Of-World

Objects that are part of the playsim but do not exist in the world. The
`EventHandler`s used to manage the rando state, for example.

## Position

The position of an object in the Doom world space, as an (X,Y,Z) coordinate triple.
Also contains information about what map it comes from.

Some *Locations* are marked "virtual", meaning they exist for the purposes of the
randomizer but don't have a fixed position in the world, and are "visited" by
other means (such as finishing a level).

## Tuning

A process of automatically improving the randomizer logic for a given WAD by
analyzing playthrough records. When you first import a WAD the logic is fairly
rough because it can't tell what keys you need to reach which items; by observing
actual play, it can improve the logic and produce more varied randomizations.

## Region

A collection of related *Locations*. In GZAP there is a one-to-one mapping between
Regions and maps. Internally, a Region contains all of the Locations within it,
along with map-wide flags: whether it's accessible, whether it's completed, and
what map-specific items (keys, automap) the player has for it.

## zspp

A simple zscript preprocessor that handles namespacing and some transformation of
debug directives. `.zs` files in the repo are inputs; `.zsc` files are what
actually gets loaded by gzDoom.

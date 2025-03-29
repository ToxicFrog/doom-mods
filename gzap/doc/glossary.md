# Glossary of Terms

It can get confusing wrangling stuff that is modeled in both the game and in the
randomizer but in different ways and for different purposes, so this file holds
the terminology I've settled on and try to keep the code in line with.

## Check

An *in-world* object associated with a *Location*. This is what the player actually
sees and touches in-game. It is mostly just a visible, collectable token, with the
actual randomizer state stored *out-of-world*.

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

## Item Category

An internal category assigned by the scanner and used by the randomizer to make
decisions about which items are replaced with checks and which ones are progression,
useful, or filler.

The current list of categories is:
- `key`: keycards, skulls, etc; specific to a single level
- `weapon`: any sort of weapon
- `map`: automaps
- `big-health`: health that restores at least 50%
- `small-health`: health that restores less than 50%
- `big-armor`: megaspheres and armour suits
- `small-armor`: armour shards
- `big-ammo`: backpacks and combined mana pickups
- `medium-ammo`: ammo that restores at least 20% of max
- `small-ammo`: all other ammo
- `powerup`: time-limited powerups like radsuits and blurspheres
- `tool`: items you can carry with you and use later (excluding health/armour), like the tome of power

## Location

The *out-of-world* data about a location where a randomized item can be placed.
Contains information about how to display it, how to locate the actor to replace
in the world, and how to report its collection to Archipelago.

## Out-Of-World

Objects that are part of the playsim but do not exist in the world. The
`EventHandler`s used to manage the rando state, for example.

## Position

The position of an object in the Doom world space, as an (X,Y,Z) coordinate triple.

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

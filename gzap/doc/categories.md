# Item and Location Categories

This document is mainly aimed at logic developers, but it may also be useful to
players who want a better understanding of exactly how the categories in the
yaml match up to items and locations in the game.


## How categories are assigned

The wad scanner considers every actor in the level. Any actor it can assign a
category to (based on its own internal heuristics or on the configuration in the
`GZAPRC` lump) gets a corresponding entry in the logic file.

When loading the logic, the apworld creates both an item and a location from
each entry. Usually, these are both assigned whatever categories the scanner
produced; in a few cases it automatically adds additional categories (but it
never removes them).

In the logic file and the yaml, categories are stored as hyphen-separated
strings, e.g. "small-health" denotes an item belonging to both the `small` and
`health` categories.

While any category appearing in the logic file will be recognized by the
apworld, and can be used via the advanced options in the yaml, the categories
listed in this file have special handling by the generator, extra support in the
yaml, or both. Logic that can sensibly fit its items into these categories is
strongly encouraged to do so rather than making up new ones.


## Special categories

### `key`

A keycard, skull, quest item, or similar. Keys are always progression items and
are always specific to a single level or cluster. Keys can be toggled from the
inventory screen and hinted from the level select. Once received, a player has
a key forever; it cannot be used up.

### `weapon`

Any sort of weapon. Weapons are always progression items and are used in combat
logic.

### `maprevealer`

Computer area maps, map scrolls, and similar. Since AP handles maps specially,
anything categorized as a `maprevealer` will produce a location, but will not
add an item to the pool.

### `ap_progression`

Forces this item to be marked as progression. Normally unneeded (`weapons` and
`keys` are always considered to be progression), but if you are writing custom
logic, you will need to add this to any other item that the logic requires.

If you mark an item `ap_progression`, you can also use `ap_skip_balancing` to
exclude the item from progression balancing and `ap_deprioritized` to avoid
placing the item in priority locations, which is useful for progression items
that are needed in large quantities and not particularly useful otherwise.

### `ap_useful`, `ap_trap`

Marks the item as particularly useful or as a trap, respectively. Does not in
any way affect logic, just how the item is categorized in AP.


## Filler Categories

All filler items have at least two categories, a *size* denoting their power
level (which, in most wads, also correlates with rarity), and a *kind*
indicating what the item actually does.

An item can have multiple kinds; for example, a megasphere, which restores both
health and armour, is `big-health-armor`.

Items belonging to multiple categories are usually sized by the most sigificant
of their effects, so e.g. something that gave you 200 health and 5 shells would
be `big-health-ammo`.

### Size categories: `big`, `medium`, `small`

All filler items should have one of these. Any that do not will be assigned the
`unknown_size` category by the scanner.

By default, the yaml randomizes 100% of the `big` items, and does not touch
`small` or `medium` ones.

The recommendations below, for where to draw the lines between the size
categories for different kinds of items, are guidelines, not hard rules; do what
makes sense for the wad you are writing logic for. The wad scanner attempts to
follow these guidelines, but cannot always derive the necessary information from
the items it scans.

### `health`

Items that restore health. Typically, if it restores 100+ health it's `big` and
if it restores less than 25 it's `small`.

### `armor`

Items that restore armour. (Note that the category name lacks a "u" to match the
engine's internals.) This has the same breakpoints as health, but is multiplied
by the armour's save percentage -- so blue armour (200 points × 50%) is `big`,
but green armour (100 points × 33%) is `medium`.

### `ammo`

Items that restore ammunition. In Doom and Heretic there are only two sizes of
each ammo refill, `small` and `medium`, with `big` reserved for the backpack.
Other wads may divide things up differently.

### `defence`

Items that protect you from harm by means other than health or armour. Generally
speaking, something that lets you stop worrying about attacks entirely is `big`,
while something that merely lets you worry less (e.g. Hedon's stoneskin potion)
is `medium`. Items that provide an unreliable or highly situational protection,
like the blursphere, are `small`.

### `attack`

Items that improve your attacks or provide attacks themselves (but which are not
weapons). These can be tricky to size, but generally, a single-use attack is
worth less than a buff unless it's a very powerful attack (or a very weak or
situational buff).

`big` is currently only used by the Horn of Plenty, which temporarily gives you
infinite ammo. `medium` is the Tome of Power and most Hedon attack buffs. `small`
attacks include the morph ovum and time bomb of the ancients.

### `tool`

Utility items that don't fall neatly into one of the other categories, such as
nightvision, speed buffs, and summons.


## Implicit categories

These categories are not used in the logic file, but are used by the apworld,
either to add to locations and items from the logic file, or for items and
locations that it creates from scratch.

### `secret`

Locations only. This means the location is inside a secret sector, or inside a
region marked with `flag/secret`.

### `sector`, `marker`

Locations only, and only when paired with `secret`.

### `ap_map`

Item is an AP automap (reveals the map, and depending on player settings,
reveals the checks and/or extra information about them).

### `ap_level`, `ap_victory`

Item is an AP level access token or AP level clear token.

### `ap_flag`

Archipelago internal. Denotes an item that affects AP behaviour but does not
turn into a physical object in-game.

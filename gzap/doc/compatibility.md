# Compatibility Notes

## General notes

### Vanilla-ish (limit-removing, boom, udmf, etc) megawads

These should generally work. If you encounter one that doesn't, please report it
as a bug (and include a link to the wad and, if you have one, a copy of the logic
file).

### Special `MAPINFO` settings

In order for some features to function correctly, gzAP needs to generate its own
`MAPINFO` lump. Wads that use `MAPINFO` to modify map flags may not function
correctly, depending on the flags. Unfortunately there is no good, general-purpose
way to do this, so I am somewhat playing whack-a-mole with `MAPINFO` features that
break maps if not supported.

### Single maps

Not currently supported.

These are unlikely to work well unless they have lots of keys, as otherwise
everything is in logic at once. Even if they do have lots of keys, tuning will
be necessary for the map to be playable at all.

### Single-use doors/elevators

In order to support co-op play, most Doom maps are designed so that you can
finish the map even if you respawn from the start partway through. This is not
universally true, however (even in the official IWADs) and some levels can get
"stuck" if you partially complete them and then return to the start (either by
respawning when you die, or by leaving the level and returning in persistent
mode).

This can be worked around by resetting the level; without persistent mode you
can do this by leaving the level and returning to it, and with persistent mode
you can use the "reset" command at the bottom of the level select screen.

### Handling of weapon drops

Things dropped by enemies are not considered checks, so e.g. shotguns dropped
by Sergeants are not checks and are not considered to be in logic.

There is an in-game setting (`ap_suppress_weapon_drops`) which can be used to
disable this; weapons will still drop from enemies but will be converted into
ammo when picked up, depending on the setting.

Note that some mods (Trailblazer is known to do this) will show you the weapon
pickup message even if the weapon is converted into ammo, but this is purely a
cosmetic issue and does not affect gameplay.

### DeHackEd

Pickups modified by DEHACKED should still be detected as checks.

### Secret things

Secret *sectors* are properly supported and can be included as checks in
themselves (i.e. stepping in the sector counts as a check, in addition to any
items it contains).

Items located in secret sectors are considered "secret checks" for the purposes
of item placement logic. Items that you need to pass through a secret sector to
reach, but which are not themselves in that sector, are *not* considered secret,
so this is not 100% reliable.

`SecretTrigger` items, which count as finding a secret when picked up, are not
currently supported.

### gzDoom mods

Depends heavily on the mod. Mods that rely on EventHandlers will generally
work, as will mods that use `x replaces y` or `CheckReplacement()`; gzAP gives
you weapons and powerups by spawning them where you're standing, rather than
inserting them directly into your inventory, so anything that properly replaces
items at spawn time should work.

Mods that delete or move things around, or replace inventory/weapons with things
that aren't those, will tend to cause problems, since gzAP relies on actor position
to match up randomizer locations with in-game objects.

#### Mods with custom difficulty settings

This includes Pandemonia and Rust & Bones, among others.

These should work fine, as long as you set the `spawn_filter` in the yaml to match
the spawn filter of the difficulty selection you're using -- e.g. if you're playing
R&B on Normal, you want "easy", not "medium", unlike stock Doom.

#### DoomRL Arsenal

Sometimes spawning a soulsphere from your inventory just doesn't give you anything,
presumably because it confuses the DRLA randomization machinery.

#### AutoAutoSave

Installing AAS causes some checks to give you both the original item and the
item it was replaced with, and also causes AAS itself to not function properly.
This happens even if AAS is turned off in the settings.

### Total conversions

TCs like Ashes 2063 or Hedon Bloodrite probably will not work out of the box,
just because they add a lot of new mechanics, specially scripted key items, etc.
That said, I would very much like to have to support for them -- I just want to
have all the basics nailed down first before I get into Hedon rando.

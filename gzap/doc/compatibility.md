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

### Handling of weapon drops

Things dropped by enemies are not considered checks, so e.g. shotguns dropped
by Sergeants are not checks and are not considered to be in logic.

If this annoys you, there's a configuration setting to turn off enemy weapon drops
entirely, or to restrict them to only weapons you've already found by other means,
or only weapons that share a slot number with a weapon you already have.

### DeHackEd

Pickups modified by DEHACKED should still be detected as checks.

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

### Total conversions

TCs like Ashes 2063 or Hedon Bloodrite probably will not work out of the box,
just because they add a lot of new mechanics, specially scripted key items, etc.
That said, I would very much like to have to support for them -- I just want to
have all the basics nailed down first before I get into Hedon rando.

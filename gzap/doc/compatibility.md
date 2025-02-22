# Compatibility Notes

## General notes

### Vanilla-ish (limit-removing, boom, udmf, etc) megawads

These should generally work. If you encounter one that doesn't, please report it
as a bug (and include a link to the wad and, if you have one, a copy of the logic
file).

### Single maps

Not currently supported.

These are unlikely to work well unless they have lots of keys, as otherwise
everything is in logic at once. Even if they do have lots of keys, tuning will
be necessary for the map to be playable at all.

### Handling of weapon drops

Things dropped by enemies are not considered checks, so e.g. shotguns dropped
by Sergeants are not checks and are not considered to be in logic.

### DeHackEd

This depends on what DEH is used for. In particular, using it to patch items
may cause them not to be detected as checks; a DeHacked weapon pickup will be
left where it sits and not considered in logic. For example, the Dehacked chainguns
in Going Down Turbo are not considered checks. Everything else should work fine,
but a wad that makes heavy use of DEH items may end up with few/no checks.

### gzDoom mods

Depends heavily on the mod. Mods that rely on EventHandlers will generally
work, as will mods that use `x replaces y` or `CheckReplacement()`; gzAP gives
you weapons and powerups by spawning them where you're standing, rather than
inserting them directly into your inventory, so anything that properly replaces
items at spawn time should work.

Mods that delete or move things around, or replace inventory/weapons with things
that aren't those, will tend to cause problems, since gzAP relies on actor position
to match up randomizer locations with in-game objects.

### Total conversions

TCs like Ashes 2063 or Hedon Bloodrite probably will not work out of the box,
just because they add a lot of new mechanics, specially scripted key items, etc.
That said, I would very much like to have to support for them -- I just want to
have all the basics nailed down first before I get into Hedon rando.

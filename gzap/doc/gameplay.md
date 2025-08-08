# Gameplay Guide

This assumes that you are already familiar with [the basics of Archipelago](https://archipelago.gg/faq/en/),
and focuses mainly on things specific to gzArchipelago.

## Overview

The default goal is to beat every level. It is sufficient to exit a level (via
the normal or secret exit or, where applicable, by killing the boss); you don't
need to kill every enemy, collect every item, or find every secret. The YAML
lets you adjust this goal: requiring only a certain number of levels and/or
specific levels. (You could, for example, set yourself a win condition of "beat
every boss level + half the levels overall".)

Each level has an access code, and you cannot enter the level at all until you
have found that code. These codes, along with keys and weapons, are considered
progression items. Each level also has a fullmap, which is considered useful,
but not progression.

## Settings

gzArchipelago has a *lot* of settings that can be adjusted in-game rather than
via the YAML. I won't try to document them all here, but you can adjust
inventory behaviour, automap behaviour, deathlink, how weapons found outside of
AP are handled, how checks are displayed, and more. These settings can generally
be adjusted mid-game without problems, and I recommend looking through them
before your first game.

## Check icons

<table>
 <tr><th>Icon</th><th>Meaning</th></tr>
 <tr>
  <td><img src=images/filler.png width=64/></td>
  <td>A filler item. The meaning of "filler" varies widely between games and can be anything from "a single bullet" to "a permanent stat upgrade", but whatever this is it won't be <i>required</i> to finish anyone's game.</td>
 </tr>
 <tr>
  <td><img src=images/useful.png width=64/></td>
  <td>A useful item. This is likewise not required, but is more useful than a filler item.</td>
 </tr>
 <tr>
  <td><img src=images/progression.png width=64/></td>
  <td>A progression item. This item is, at minimum, needed to unlock new areas for someone, and may be needed to finish the game.</td>
 </tr>
 <tr>
  <td><img src=images/useful-progression.png width=64/></td>
  <td>An item that is both needed for progression and extra useful.</td>
 </tr>
 <tr>
  <td><img src=images/trap.png width=64/></td>
  <td>A harmful trap. gzArchipelago doesn't have traps (yet), but in a multiworld game you may find traps that get sent to other people. Note that depending on your settings, this might instead show up as a filler or even progression item!</td>
 </tr>
</table>

Depending on your settings, checks may also show an item in the center, floating
above them, or both. The item above represents the original item that was at
that location, and can be useful when still learning the maps since checks are
identified in the tracker by what item they replaced. The item in the center
represents the item you'll find upon picking it up. (If it's an item for another
game, you might see nothing, or you might see a generic graphic of some kind
based on the item name.)

## The interface

### Level select

Most of the new interface added by gzArchipelago is accessed via the `AP level select`
keybinding. This brings up the level selector, which also functions as a simple
in-game tracker:

<img src=images/level-select.png height=400>

This shows you which maps you have access codes to, which ones you've cleared,
which fullmaps you have, which keys you have found, how many items you've found
on each map, and your progress towards completion and in-game time. Placing the
cursor on a map will also show you a detailed breakdown of its status, including
a list of all locations in that level you have yet to check. If hints are
enabled (or if you are playing solo), you can also press `shift-H` to request an
appropriate hint; it will first hint the access code the level (if you don't
already have it or a hint to its location), then any keys you are missing.

At the bottom of the list is a button that will take you back to the gzArchipelago
intermission level (if you want to leave your current level but not immediately
start a different one). If persistent mode is on, there will also be an option
to reset all levels -- unfortunately there is not currently any way to reset
only some levels and leave the rest alone.

If you have [Universal Tracker](https://github.com/FarisTheAncient/Archipelago/releases)
installed, and are connected to the AP client, the `Unchecked Locations` list
will additionally colour-code the entries to tell you which ones UT thinks are
in logic, technically out of logic but still reachable (e.g. because you've
unlocked a late-game level and it doesn't think you have enough guns), or fully
unreachable.

### Inventory

The other new piece of interface is the inventory screen, accessed via the
`AP inventory` keybinding:

<img src=images/inventory.png height=400>

Most items found via Archipelago, by default, are not granted to you immediately
but are held in an AP-specific inventory from which you can request items at any
time. This means you have to remember to use it to top up your armour, health,
and ammo, but also means that you can save crucial items like invulnerability
spheres for when they are actually useful. This is particularly important in
async games where you might receive a hundred items when you first connect but
none while actually playing.

### Automap

The automap is capable of displaying check locations; depending on your settings,
you may need to find the fullmap for the level first, or doing so might reveal
additional information about the checks. This works both with the full-screen map
built into GZDoom, and with mod-supplied maps like FlexiHUD.

## Save/load behaviour

Archipelago state is largely independent of saving and loading. If you save your
game, check a location, and then load, the game remembers that that location was
checked and does not let you send a duplicate item by checking it again.

## Respawns

By default, when you die, GZDoom loads your most recent savegame. If you don't
have a save, it restarts the level with a basic starting inventory.
gzArchipelago additionally lets you turn on respawning in the YAML; if this is
on, then on death you will respawn at the start of the level with full health
and your inventory otherwise unchanged.

Most Doom maps are designed to be co-op compatible and will remain beatable after
respawning. There are exceptions, where single-use switches, elevators, or the
like make it impossible to progress through the level after a respawn; in those
cases you must either reset the level (by leaving and coming back), load a saved
game, or use a cheat like `noclip`.

## Persistent mode

Persistent mode is another YAML option that preserves the state of each map even
after you leave it, similar to how Hexen's maps work. When you return to a map,
you will appear at the normal spawn point, but everything else -- enemies, items,
doors, switches, etc -- will be just as you left it.

## Differences between solo and multiworld play

In solo play, items are granted as soon as checks are touched, and hints are
free -- you are on the honour system when it comes to not abusing hints.

In multiworld play (or solo play with the client connected), items are granted
once the server replies that it has registered the check as collected. Depending
on the game this can sometimes result in a delay of a second or more before
receiving the item. (If you aren't receiving items *at all*, double check that
your client is still connected to the host.) Hints may cost points depending on
what the host has configured, and asking for a hint when you don't have enough
points will do nothing.

In multiworld play, you can also chat with other players using the same in-game
chat interface used for deathmatch and co-op games; `t` by default.

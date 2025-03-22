# Setup and Play

This document describes how to get up and running with gzArchipelago, for players
who just want to play one of the [supported wads](./support-table.md).

## First-time setup

Download the [apworld](../../release/gzdoom.apworld) and add it to Archipelago.

Download the [latest version of the mod](../../release/gzArchipelago-latest.pk3)
and add it to your gzdoom load order (it doesn't much matter where).

If you are new to using GZDoom, there a [newbie guide](./gzdoom_newplayers.md) available.

Start up gzdoom, go into the mod settings, and configure it to your taste. Make
sure to bind controls for Level Select and Inventory.

## Game Generation

This works the same as in any other Archipelago game: `Generate Template Options`
to get an example YAML file, edit it to your taste, then either `Generate` it
yourself, or send it to the host who does so. Don't forget to select a wad --
otherwise it will select one at random from all the wads it supports.

The zip file emitted by the generator will contain, in addition to the AP data
package and the spoiler log, a `pk3` file with your name on it. Add this to your
load order *at the end*, or at least, after GZAP.pk3 and after whatever wad you're
playing.

## Single-world

If you're playing solo, that's basically all you need to do. Start the game up
and when you start a new game, it should drop you into the Archipelago level
select menu. This lists:
- all the levels;
- how many randomized items each one contains, and how many you've found;
- which keys each level has, and which one you've found;
- whether you've found the map for each level; and
- whether you've beaten the level.

From here you can jump to any unlocked level, which will put you at the start of
the level with everything you've collected so far. The `items` counter is repurposed
to show the number of checks remaining in the level.

The win condition is to beat (reach the exit of) every level; you don't need to
collect every item.

As you check locations, any keys, level accesses, or maps you find are added to
your inventory immediately. Armour, weapons, powerups, etc go into a separate
"randomizer inventory". You can open this and spawn any of the items in it at any
time. If you find yourself lacking firepower or running out of health or armour,
check your inventory and see if maybe you picked up a megasphere or plasma rifle
that you forgot about.

## Multi-world

The in-game behaviour is effectively the same as in single-world; the difference
is in the setup.

If playing multiworld, you should first start up Archipelago and start the
`GZDoom Client`. This will show you some help text, including some extra command
line flags for gzdoom. **You must use these flags or gzdoom and archipelago
will be unable to communicate**.

Start gzdoom and once you're in-game, you should see messages in the client
indicating that it's connected to gzdoom. Click `connect` to connect to the
Archipelago host and you're good to go.

You can, at any time, save your game and exit; next time you start gzdoom the
client will reconnect and send you anything you missed.

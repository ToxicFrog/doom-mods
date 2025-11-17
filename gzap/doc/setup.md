# Game Setup

This document describes how to get up and running with gzArchipelago, for players
who just want to play one of the [supported wads](./support-table.md). If you want
to play an unsupported wad, see [this documentation](./new-wads.md).

## First-time setup

Download the [apworld](../../release/gzdoom.apworld) and add it to Archipelago.
If the WAD you want to play isn't in the "Core WADs" list in the
[support table](./support-table.md), you should also download the apworld for
that wad from the [addon apworlds directory](../../release/apworlds/).

Download the [matching version of the mod](../../release/gzArchipelago-latest.pk3)
and add it to your gzdoom load order (it doesn't much matter where).

Start up gzdoom, go into the options menu, and use the `gzArchipelago Options`
to configure the mod to your taste. Make sure to bind keys for `AP level select`
and `AP inventory`.

If you are new to GZDoom or to GZDoom modding, you may want to read the
[GZDoom quickstart guide](./gzdoom_newplayers.md), which explains the above in
more detail.

## Game Generation

This works the same as in any other Archipelago game: `Generate Template Options`
to get an example YAML file, edit it to your taste, then either `Generate` it
yourself, or send it to the host who does so. Don't forget to select a wad --
otherwise it will select one at random from all the wads it supports.

The zip file emitted by the generator will contain, in addition to the AP data
package and the spoiler log, a `pk3` file with your name on it. Add this to your
load order *at the end*, or at least, after gzArchipelago.pk3 and after whatever
wad you're playing. **You must include both gzArchipelago.pk3 and the generated
pk3 in your load order.**

## Single-world

gzArchipelago has fully integrated solo-play support; you do not need to host a
game or start the client. Simply start up the game and begin playing. If you are
playing across multiple sessions, you can safely save and exit, and resume (via
`Load Game` in the main menu) later.

If you do want to run the client -- which may be useful, since that provides
automatic recording of [tuning files](./new-wads.md) and, if
[Universal Tracker](https://github.com/FarisTheAncient/Archipelago/releases) is
installed, tracker integration -- follow the same instructions as for multiworld
play, below.

Once in-game, consult the [gameplay guide](./gameplay.md) for more details.

## Multi-world

If you are joining a multiworld game, you will need to start an external client
to handle communication between GZDoom and the Archipelago host.

Start up Archipelago and click `GZDoom Client`. This will show you some help
text, including some extra command line flags for GZDoom. **You must use these
flags or GZDoom and Archipelago will be unable to communicate**.

Enter the AP host address and click `Connect`. You should see a message
indicating that it has connected to the server and is awaiting information from
GZDoom.

Start GZDoom. Select `New Game`, choose a difficulty level matching what you
selected in the YAML, and once the game loads in you should see a green message
at the top of the screen saying that the AP connection is working. This should
be accompanied by messages in the AP client showing that you have joined the
game.

If you need to stop playing and resume later, you can save and exit your game as
normal; when returning to it, restore your save (via `Load Game` in the main
menu; **do not** start a new game and then load your game from there) and AP
will sync any items that you missed while offline.

Once in-game, consult the [gameplay guide](./gameplay.md) for more details.

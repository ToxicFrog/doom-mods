# Adding New WADs

Internally, gzArchipelago works by loading a *logic file* for each supported wad.
This file contains a record of all levels and actors in the wad; optionally, it
also contains a *tuning journal*, information recorded from actual play that it
uses to improve the randomizer logic.

This file documents how to produce and update these files. It will use Demonfear
(DMONFEAR.WAD) as an example.

⚠️ In a few wads, this process produces rapid screen flashing.


## Generating a new logic file

The easy way to do it, if you are comfortable in the shell, is to use the
`tools/ap-scan` script in this repo. If you're not, though, you can do it in
gzdoom.

First, start up gzdoom with your wad (and, ideally, no other mods except GZAP)
loaded:

    gzdoom -iwad doom2.wad -file DMONFEAR.WAD -file gzArchipelago-latest.pk3

Then you need to create a logfile. Unfortunately the mod **cannot do this for you**,
you have to do it yourself. Open the console and:

    logfile Demonfear

While you're here, you might want to change some settings that will make the scan
go a lot faster. (Don't forget to change them back later!)

    disableautosave 1
    wipetype 0

From here, you can go into the mod options and use the controls there to start
a scan, or you can do it, too, from the console:

    ap_scan_levels MAP01
    ap_scan_recurse 1
    netevent ap-scan:start

In either case, it will start the scan. If it encounters any cutscenes, you may
need to fast forward through them for it. When it finishes, quit and the scan
results will be in the `Demonfear` file (or whatever filename you passed to
the `logfile` command).

### Multiple episodes and standalone maps

Some WADs are divided into episodes or have maps that aren't reachable from the
normal set of levels. For these, you can specify multiple starting levels. For
example, to scan Doom 1:

    ap_scan_levels "E1M1 E2M1 E3M1 E4M1"
    ap_scan_recurse 1
    netevent ap-scan:start

Note that the quotes around the map names are mandatory in the console, and should
be omitted if scanning from the GUI.

### Skipping levels

There are two cvars that control this.

Levels listed in `ap_scan_skip` (which has the same format as `ap_scan_levels`)
will be used to find other levels, but will not themselves be included in the
logic. This is useful for cutscenes, interstitial hubs, etc that are not meant
to be included in the randomizer but have exits leading to other levels that
are.

    ap_scan_skip "E1END E2END CREDITS"

Levels listed in `ap_scan_prune` will be excised from the scan entirely, and
will not be searched for exits to other levels.

    ap_scan_prune "MAP31 MAP32"

### Overriding scanner behaviour

Some wads contain items that gzArchipelago's automatic item classifier does not
properly handle. For these, you can write a `GZAPRC` file defining how to handle
them. All `GZAPRC` files, in any `pk3`, `wad`, or directory passed to gzdoom using
`-file`, will be loaded.

It can be used to override how items are classified for randomization (for example,
reclassifying something from "tool" to "powerup"), exclude items from randomization,
and include items that would not normally be included. It can also be used to add
a different item to the item pool than what the scanner finds.

By including a `scanner { ... }` block, you can also set default values for the
scanner configuration cvars, controlling which levels are scanned and which are
ignored.

This repo contains a [several examples](../config/) in the config directory.

If you are a mapper, you can include a `GZAPRC` lump in your wad and it will be
automatically detected and loaded by gzArchipelago.

### Custom location names

You can define custom names for locations that are more descriptive than the
default item-and-coordinate based ones, like "Stimpack in GreenArmor secret" or
"Megasphere near blue key". To do this, find the `AP-ITEM` or `AP-SECRET` entry
for the location you want to rename in the logic file, and add a `"name":` key
to it. See the Doom 2 logic for an example.

Names do not have to be unique; the randomizer will add a unique suffix if there
are duplicate location names in the logic.

## Publishing your logic

gzArchipelago can load your logic and tuning files from disk, as long as they're
in the right place, but for sharing with other people (like a game host) it's
convenient to create an apworld for them, or add them to an existing one.

### Loading files without adding them to the apworld

When still developing, it's convenient to be able to load your logic and tuning
files without needing to re-pack the apworld each time.

On startup, the apworld will have created a `gzdoom` directory inside your
Archipelago directory, used to communicate with gzdoom while playing. This
directory also contains `logic` and `tuning` directories; any logic or tuning
files placed in them will be loaded automatically (and, in the case of logic
files, will override the builtin logic if they have the same name), allowing you
to rapidly change and test your work without repacking the apworld.

Note that tuning files in this directory do not apply to logic files inside an
apworld; if you want to add tuning to a wad that has logic in the apworld, you
will need to either pack your tuning files into the same apworld to test, or
unpack the logic from the apworld while testing.

### Adding the logic file to an apworld

- Open gzdoom.apworld in a zip viewer
- Add the logic file to the `gzdoom/logic/` directory
- Save and quit

That's it! It'll be automatically loaded next time you start Archipelago.

### Publishing a new apworld

To do this, you just need a zip file with a `.apworld` extension, containing a
minimal `__init__.py` along with `logic` and `tuning` directories. See the
[extras apworld](../../release/ap_gzdoom_extras.apworld) for an example.

There is a restriction on apworld naming: gzdoom addon apworlds must have an
apworld name that **alphabetically sorts before gzdoom.apworld**. This is why
the featured and extras apworlds have names starting with `ap_gzdoom_` rather
than just `gzdoom_`.

## Tuning a logic file

When you play a multiworld game, a tuning file will be automatically created
in the `gzdoom/tuning` directory in your Archipelago directory, with the same
name as the wad you're playing. If you play the same wad multiple times, it
will create multiple, numbered tuning files, all of which will be loaded by the
apworld.

When you play single-world, you can accomplish the same thing with the `logfile`
console command. (Or you can just leave the AP client running in the background
-- it doesn't need to connect to the AP server to create the tuning file for
you.)

The files in `<AP dir>/gzdoom/tuning/` will be loaded automatically; to "bake it
in" to the apworld, use the same procedure as adding a logic file, but put the
files in the `gzdoom/tuning/` directory inside the apworld, rather than
`gzdoom/logic/`.

### Keys not detected by the scanner

Some wads contain keys that are not visible at scan time, because they are
spawned as enemy drops or via scripts. These will be not be added to the item
pool, but when picked up normally, gzArchipelago will detect them and emit an
appropriate `AP-KEY` message into the tuning file.

Once you finish tuning, you must move these messages from the tuning file to the
logic file; to function properly they *must* be in the main logic file, and
failure to do so will prevent the apworld from initializing.

### Tuning without randomizing

The randomizer supports a "pretuning mode" which can be used to perform tuning
using the original item locations from the wad. To enable this, just set
`pretuning_mode` to `true` in your YAML. This will override most other settings,
and give you a game with the original item placements, all levels unlocked and
mapped from the start, and no starting keys.

Additionally, when picking up a key in pretuning mode, it will be considered
"disabled": it will not be placed in your inventory and will not be recorded in
the tuning data when picking up items. This allows you to continue collecting
things until you have fully exhausted all items reachable without the key. At
that point, you can open the AP inventory menu and toggle the key on, then
continue playing.

Note that while you can toggle keys back off, doing so makes it *very easy* to
create invalid logic; it is recommended that you not do this unless you really
know what you're doing.

### Unreachable checks

You may encounter checks that are unreachable in normal play. For example, Doom
2 MAP07 ("Dead Simple") contains a BFG in a hidden room that can only be opened
in multiplayer.

If you encounter one of these, you can mark it unreachable using the `ap_scan_unreachable`
cvar. You can mark the next check you touch unreachable (and then use `noclip` to
actually reach it):

    ap_scan_unreachable 1

Alternately, you can mark every check you touch for the rest of the level:

    ap_scan_unreachable 2

In the latter case, it will mark all remaining checks when you exit the level,
so you don't need to run around noclipping to all of them -- just set it to 2
and touch the exit.

On future runs, unreachable checks will still be present in the world, but will
be hard-coded to contain a 1-point health restore filler item; they will never
contain progression items or items from someone else's game. They will also be
displayed with a greyscale icon.

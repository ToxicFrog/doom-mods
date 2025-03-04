# Adding New WADs

Internally, gzArchipelago works by loading a *logic file* for each supported wad.
This file contains a record of all levels and actors in the wad; optionally, it
also contains a *tuning journal*, information recorded from actual play that it
uses to improve the randomizer logic.

This file documents how to produce and update these files. It will use Demonfear
(DMONFEAR.WAD) as an example.


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

## Adding the logic file to the apworld

- Open gzdoom.apworld in a zip viewer
- Add the logic file to the `gzdoom/logic/` directory
- Save and quit

That's it! It'll be automatically loaded next time you start Archipelago.

### Loading files without adding them to the apworld

When still developing, it's convenient to be able to load your logic and tuning
files without needing to re-pack the apworld each time.

On startup, the apworld will have created a `gzdoom` directory inside your
Archipelago directory, used to communicate with gzdoom while playing. This
directory also contains `logic` and `tuning` directories; any logic or tuning
files placed in them will be loaded automatically (and, in the case of logic
files, will override the builtin logic if they have the same name), allowing you
to rapidly change and test your work without repacking the apworld.

## Tuning a logic file

When you play a multiworld game, a tuning file will be automatically created
in the `gzdoom/tuning` directory in your Archipelago directory, with the same
name as the wad you're playing.

When you play single-world, you can accomplish the same thing with the `logfile`
console command.

The file in `<AP dir>/gzdoom/tuning/` will be loaded automatically; to "bake it in"
to the apworld, use the same procedure as adding a logic file, but put the file
in the `gzdoom/tuning/` directory inside the apworld, rather than `gzdoom/logic/`.
If a file already exists there for this WAD, simply append the new tuning data
to it.

### Unreachable checks

You may encounter checks that are unreachable in normal play. For example, Going
Down Turbo MAP12 has a red key that exists purely for visual effect and cannot
be collected by the player.

If you encounter one of these, you can mark it unreachable using the `ap_scan_unreachable`
cvar. You can mark the next check you touch unreachable (and then use `noclip` to
actually reach it):

    ap_scan_unreachable 1

Alternately, you can mark every check you touch for the rest of the level:

    ap_scan_unreachable 2

In the latter case, it will mark all remaining checks when you exit the level, so
you don't need to run around noclipping to all of them -- just set it to 2 and
touch the exit.

On future runs, unreachable checks will still be present in the world, but will
be hard-coded to contain Doom filler items; they will never contain progression
items or items from someone else's game.

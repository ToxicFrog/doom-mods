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

    gzdoom -iwad doom2.wad -file DMONFEAR.WAD -file GZAP-latest.pk3

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

## Adding the logic file to the apworld

- Open gzdoom.apworld in a zip viewer
- Add the logic file to the `gzdoom/logic/` directory
- Save and quit

That's it! It'll be automatically loaded next time you start Archipelago.

## Tuning a logic file

When you play a multiworld game, a tuning file will be automatically created
in the `gzdoom-ipc` directory in your Archipelago directory, named `<wad name>.tuning`.

When you play single-world, you can accomplish the same thing with the `logfile`
console command.

In either case, just appending the contents of the file to the existing logic
file will act as tuning data for it.

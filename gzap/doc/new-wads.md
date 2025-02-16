# Adding New WADs

Internally, gzArchipelago works by loading a *logic file* for each supported wad.
This file contains a record of all levels and actors in the wad; optionally, it
also contains a *tuning journal*, information recorded from actual play that it
uses to refine the randomizer logic.

This file documents how to produce and update these files. It will use Demonfear
(DMONFEAR.WAD) as an example.


## Generating a new logic file

### Creating the file

Generating a new logic file is straightforward; it's just a matter of loading the
mod and running some console commands. In most cases you can do all of this on
the command line:

    $ gzdoom -iwad doom2.wad -file DMONFEAR.WAD \
        -skill 3 -warp 1 +'logfile Demonfear.log; wait 1; netevent ap-scan'

This will start up the game, immediately warp you to the first level, and then
start the scanner. The `logfile` command tells it where to write the logic to
and is **mandatory**; otherwise nothing will be written. You may need to skip
through the intermission screens, but otherwise it should be fully automated.

If this doesn't scan all the levels properly -- for example, if the wad is divided
into multiple episodes and exits back to the titlemap between them -- just use the
`map` command in the console to switch to the next map and then restart the scan
with `netevent ap-scan`.

Once you're done, quit the game and you have your logic file.

Note that logic files are (currently) difficulty-specific: if you want to play on
multiple difficulties, you need a separate logic file for each difficulty.
<!-- TODO: support multi-difficulty logic files -->

### Using the file

For testing purposes, you can set the environment variable `GZAP_EXTRA_LOGIC` to
the path to a logic file, and Archipelago will load it after loading all of its
built in logic. This is fine when verifying the file or playing in singleplayer.

If you are doing a multiplayer game and need to send the apworld to the host,
you can add the file by opening the apworld with your favourite zip program and
adding the logic file to the `gzdoom/logic/` directory. Once you do that it will
be detected and loaded automatically by Archipelago.


## Tuning a logic file

TODO: more detailed docs here; but basically, randomize the game, then play it
normally and append the log file full of AP-CHECK lines to the original logic
file. Next time you generate it'll use the tuned version.

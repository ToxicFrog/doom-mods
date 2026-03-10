# Adding New WADs

Internally, UZArchipelago works by loading a *logic file* for each supported wad.
This file contains a record of all levels and actors in the wad; optionally, it
also contains a *tuning journal*, information recorded from actual play that it
uses to improve the randomizer logic.

This file documents how to produce and update these files. It will use Demonfear
(DMONFEAR.WAD) as an example.

⚠️ In a few wads, this process produces rapid screen flashing.


## Generating a basic logic file

The basic logic is the catalogue of all maps in the wad and what items and
secrets they contain. In most wads, this is all that's needed to be playable.

First, start up uzdoom with your wad (and, ideally, no other mods except UZAP)
loaded:

    uzdoom -iwad doom2.wad -file DMONFEAR.WAD -file UZArchipelago-latest.pk3

Then you need to create a logfile. Unfortunately the mod **cannot do this for you**,
you have to do it yourself. Open the console and:

    logfile Demonfear.logic

While you're here, you might want to change some settings that will make the scan
go a lot faster. (Don't forget to change them back later!)

    disableautosave 1
    wipetype 0

Having done this, open the `UZArchipelago Options` from the options menu, and
scroll down to the `WAD Import Scanner` section at the bottom. Here you can set
up the scanner configuration. In most cases, setting `Levels to Scan` to a list
of all start-of-episode maps (all the `E?M1` maps for Doom and Heretic WADs,
`MAP01` for Doom 2) and leaving the other settings at default is sufficient.

Once set up, click `Begin Scanning` and wait for the process to complete. If
there are any text cutscenes, you will be required to advance through them, but
everything else should happen automatically.

If that worked, you can now [fine-tune the logic](#refining-your-logic) and
[publish the logic](#publishing-your-logic). If not, see the sections below.

### Hub-based wads

Support for these is still being tested, and full documentation is yet to be
written. The short explanation is:

- Set `extra flags` to `use_hub_logic hub_logic_exits=X,Y,Z`, where `X`, `Y`,
  and `Z` are the end-of-hub maps
- Possibly turn off recursive scanning and turn on cluster scanning, depending
  on the wad
- After scanning, you *must* do a [pretuning run](#pretuning) using the
  [subregion editor](#defining-subregions)

See the [GZAPRC](../config/GZAPRC.faithless) and [logic](../wads/faithless/) for
an example.

### Skipping maps

You may end up with maps in the output that you did not want to include,
typically as a result of the WAD including an exit to one of the stock maps
(e.g. a WAD containing MAP01-MAP10 where MAP10 includes an exit to the Doom 2
MAP11), or because the WAD includes cutscene or credits maps that don't make
sense to include in randomization.

For cutscene maps and similar, listing them under `ignore apart from exits` will
cause the scanner to check them for exits to other maps (and then scan those maps),
but not include them in the logic output.

Maps listed under `ignore completely` will be entirely skipped without checking
them for exits; the scanner will pretend they don't exist.

### Overriding scanner behaviour

Some wads contain items that UZArchipelago's automatic item classifier does not
properly handle. For these, you can write a `GZAPRC` file defining how to handle
them. All `GZAPRC` files, in any `pk3`, `wad`, or directory passed to uzdoom using
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
automatically detected and loaded by UZArchipelago.


## Refining your logic

The scanner produces "basic" logic, with one sphere per map. The result is
playable, but a bit of extra work can make it much more closely reflect the
actual structure of the WAD, and produce a better experience for players.

### Custom location names

If a location needs a hand-crafted name, and naming [the area it's in](#defining-regions)
isn't sufficient, you can do this by editing the logic file directly. Find the
`AP-ITEM` or `AP-SECRET` line corresponding to the location you want to rename,
and add `"name": "my custom name"` to it.

Names do not have to be unique; the randomizer will add a unique suffix if there
are duplicate location names in the logic.

### Autotuning

Playing through a randomized game produces a *tuning journal*, a record of which
locations you checked in what order and what keys you had when you did so. The
randomizer can use this to refine the logic. So, simply playing through the WAD
several times -- as long as you grab items whenever you can reach them, and not
just when they are in logic -- will produce improvements.

If you are playing with the AP client running, tuning journals will be written
to the `uzdoom/tuning/` directory in your AP directory. If not, you can use the
`logfile` command in-game and use the resulting log file. Just remember to copy
it to safety after each game session; it is overwritten whenever uzdoom starts.

Tuning files need to be bundled with the logic file to function; see
[publishing your logic](#publishing-your-logic).

#### Dynamically-spawned keys

Some WADs contain keys that do not exist when the map is scanned, and only appear
later (e.g. spawned by ACS or dropped by a boss). The first time you pick up one
of these keys, an `AP-KEY` message will be emitted into the journal. Once you
finish your playthrough, you must move this message from the tuning file to the
logic file emitted by the scanner for apworld to function correctly.

#### Unreachable checks

You may encounter checks that are unreachable in normal play. For example, Doom
2 MAP07 (`Dead Simple`) contains a BFG in a hidden room that can only be opened
in multiplayer.

You can mark these checks *unreachable* in the tuning journal, which will prevent
them from being included in the pool in future games. At the moment this is only
possible from the console:

- Mark the next check unreachable: `ap_scan_unreachable 1`
- Mark all checks unreachable until you exit the level: `ap_scan_unreachable 2`

In the latter case, you don't need to touch every check by hand; exiting the
level will mark all remaining checks as unreachable.

### Pretuning

Pretuning mode is a way to generate a tuning journal that describes all checks
in the game via a single playthrough. To use it, turn it on in your YAML file
and generate a singleplayer game (it is not suitable for multiworld play).

In pretuning mode, all checks spawn, regardless of item pool or difficulty
settings. Furthermore, keys, when picked up, are not automatically granted to
you; you must instead turn them on manually from the inventory screen (`I`). In
general, in each level, you will want to follow a procedure like:

- Collect every check you can reach without turning on any keys.
- Turn on one key.
- Collect every check you can reach with just that key.
- Repeat turning on keys and collecting new checks until you have collected
  every check and finished the level.

You can also turn keys back *off*, to correctly handle maps like `Tricks and Traps`
where there are a number of branching paths that each only need one key to unlock.
Make sure when doing this that there is a path from the level entrance to wherever
you are that doesn't require the keys you just disabled, or you can produce
impossible logic.

#### Defining subregions

Subregions let you group together checks that have the same logical access
requirements. This requires a bit more attention from the logic developer, but
also lets you manually adjust the logical requirements for large numbers of
checks at once, and give them more descriptive names than the auto-generated ones
without manually assigning a name to every single check.

To define a subregion, press `L` to open the logic dashboard and select
`Create/Activate Subregion`. The screen that opens will let you select an existing
subregion from the same level to switch to, or enter a name to create a new subregion.

Once you have defined a subregion, all checks you collect will be assigned to
that subregion. By default, the subregion's logical requirements are just
whatever keys you had active when you defined it; however, you can use the logic
dashboard to manually change the prerequisites.

- Keys are either optional (`-`) or required (`+`).
- Weapons are optional, required, or wanted (`?`). Currently "wanted" is the
  same as "optional", but in the future it will interoperate with weapon logic.
  "Required" imposes a hard requirement that the player have that weapon.
- Other maps and subregions are, like keys, either optional or required; a
  requirement means that the player needs to be able to reach that subregion
  or map before this one is in logic.

Changes to the requirements apply to *all* checks in that subregion, even if
they are already collected, so if two checks have different logical requirements
they **must** be in different subregions.

Once you are done with your pretuning run, select `Save Subregions to Tuning File`
from the logic dashboard in order to actually record them -- if you don't do this
they won't be saved and the tuning journal will be unusable! This will result in
a batch of `AP-REGION` messages at the end of the tuning journal. You must manually
move them to the start of the tuning journal before publishing it.


## Publishing your logic

Logic for a wad must be published as an apworld. Each apworld contains support
for one wad.

The easiest way to do this is in your browser, using the
[UZArchipelago apworld packager](https://toxicfrog.github.io/doom-mods/apworld-generator.html).
Enter a name, select your logic file (and tuning files, if any), and click the
"generate apworld" button. It will offer you the apworld as a download.

Note that your logic files *must* end with a `.logic` extension, and tuning
files with `.tuning`.

### Loading files without packaging them

This feature was available in earlier versions, but had to be removed when the
project was split into multiple apworlds, and is unlikely to return.

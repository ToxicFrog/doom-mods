
# Support Table

This file summarizes the state of support for various wads, and contains
download links for the WAD-specific apworlds. Click on the name of a WAD to
download the corresponding apworld.

Support is classified as:

- **basic**: the WAD has been scanned and is confirmed working. It is playable
  in single and multiworld but the randomizer will be very cautious about item
  placement and many things you can easily reach will be considered out of logic.
- **partial**: tuning data (i.e. detailed logic) is present for at least one
  episode's worth of levels.
- **full**: tuning data is present for all levels. A small number of individual
  items may still be using basic logic.
- **complete**: tuning data is present for all items in all levels. The logic is
  believed to be an accurate and complete description of the game.
- **problems**: testing has revealed that changes to the scanner, randomizer,
  or tuner are needed to support this properly.
- **missing**: not yet supported, but I either want to add support or know
  people are going to ask about it.

The number of levels, monsters-per-level, and checks is given as a rough guide
to the size of the wad for the purposes of rando planning with others. The check
and monster counts assumes you are playing on UV and using the default settings;
there is usually a small amount of variation across difficulties. Enabling
`medium` or `small` items will significantly increase the number of checks.

You may also want to look at the [general compatibility notes](./compatibility.md).

### Core WADs

These are the "canonical" WADs: base games and official expansion packs.

The eventual goal is to have full coverage for the official Id and Raven games,
official expansions like TNT and Sigil, and widely-used vanilla-compatible fan
IWADs like FreeDoom.

Version numbers are given so you make sure you're using the right version. If
need to identify a WAD, the [DoomWiki Resources category](https://doomwiki.org/wiki/Category:Resources)
lists all of them, with hashes. Using a different version than the one supported
here may result in glitches.

| WAD                         | Maps | Mon/Lvl | Checks | Status | Notes |
| --------------------------- | ---- | ------- | ------ | ------ | ----- |
| [Chex Quest 3]              |   15 |      83 |    242 | complete | [v1.4](https://www.chexquest3.com/downloads/); v2.0-prerelease is not yet supported. |
| [Doom]                      |   36 |      90 |    652 | basic  | v1.9ud |
| [Doom 2]                    |   32 |     116 |    640 | full   | v1.9 |
| [FreeDoom]                  |   36 |     176 |    715 | basic | [v0.13.0](https://freedoom.github.io/download.html) |
| [FreeDoom 2]                |   32 |     135 |    636 | basic | [v0.13.0](https://freedoom.github.io/download.html) |
| [Heretic]                   |   45 |     116 |   1159 | basic  | v1.3 |
| Hexen                       |      |         |        | missing | I don't like it, but if someone wants to contribute logic, feel free. |
| [Legacy of Rust]            |   16 |     212 |    359 | problems | Fully tuned, but MAP14 doesn't fully work because of [this gzdoom limitation](https://github.com/ZDoom/gzdoom/issues/2208); you will need to exclude it or make it optional. |
| [Master Levels for Doom II] |   21 |     120 |    483 | full   | |
| [No Rest for the Living]    |    9 |     141 |    202 | full   | |
| [Plutonia]                  |   32 |      95 |    509 | full   | v1.9 |
| SIGIL                       |      |         |        | missing | |
| SIGIL II                    |      |         |        | missing | |
| Strife                      |      |         |        | missing | |
| [TNT]                       |   32 |     152 |    641 | basic  | v1.9 |
| WadFusion                   | varies | varies | varies | missing | A [tool](https://github.com/Owlet7/wadfusion) for combining official WADs into one game. See https://github.com/ToxicFrog/doom-mods/pull/38 for progress of support. |

[Chex Quest 3]: ../../release/apworlds/zdoom_chex_quest_3.apworld
[Doom]: ../../release/apworlds/zdoom_doom.apworld
[Doom 2]: ../../release/apworlds/zdoom_doom_2.apworld
[FreeDoom]: ../../release/apworlds/zdoom_freedoom.apworld
[FreeDoom 2]: ../../release/apworlds/zdoom_freedoom_2.apworld
[Heretic]: ../../release/apworlds/zdoom_heretic.apworld
[Legacy of Rust]: ../../release/apworlds/zdoom_legacy_of_rust.apworld
[Master Levels for Doom II]: ../../release/apworlds/zdoom_master_levels_for_doom_ii.apworld
[No Rest for the Living]: ../../release/apworlds/zdoom_no_rest_for_the_living.apworld
[Plutonia]: ../../release/apworlds/zdoom_plutonia.apworld
[TNT]: ../../release/apworlds/zdoom_tnt.apworld

### Featured WADs

These are WADs available throught Night Dive's
[Featured Mods List](https://doomwiki.org/wiki/Featured_mods) in the
`Doom + Doom II` launcher.

| WAD                  | Maps | Mon/Lvl | Checks | Status  | Notes |
| -------------------- | ---- | ------- | ------ | ------- | ----- |
| Anomaly Report       |      |         |        | missing |       |
| [Arrival]            |   11 |     250 |    309 | basic   |       |
| [Base Ganymede]      |   27 |     149 |    344 | basic   |       |
| BTSX Episode 1       |      |         |        | missing |       |
| BTSX Episode 2       |      |         |        | missing |       |
| [Deathless]          |   36 |      65 |    432 | basic   |       |
| Doom Zero            |      |         |        | missing |       |
| Double Impact        |      |         |        | missing |       |
| Earthless: Prelude   |      |         |        | missing |       |
| Going Down           |      |         |        | missing |       |
| [Going Down Turbo]   |   32 |     163 |    486 | partial |       |
| Harmony              |      |         |        | missing |       |
| No End In Sight      |      |         |        | missing |       |
| REKKR                |      |         |        | missing |       |
| Revolution!          |      |         |        | missing |       |
| [Scientist 2023]     |   20 |     118 |    365 | basic   |       |
| Syringe              |      |         |        | missing |       |
| Tetanus              |      |         |        | missing |       |
| Trooper's Playground |      |         |        | missing |       |

[Arrival]: ../../release/apworlds/zdoom_arrival.apworld
[Base Ganymede]: ../../release/apworlds/zdoom_base_ganymede.apworld
[Deathless]: ../../release/apworlds/zdoom_deathless.apworld
[Going Down Turbo]: ../../release/apworlds/zdoom_going_down_turbo.apworld
[Scientist 2023]: ../../release/apworlds/zdoom_scientist.apworld

### Extra WADs

These are community-made WADs for which logic exists. This is a grab bag with
sigificant variation in size and style, and is basically just "everything people
played randomized and went through the effort to produce logic and tuning for".
You can generally read about them and find download links for the WADs via
[DoomWiki](https://doomwiki.org/).

#### Maps

Map packs that use vanilla or lightly-modified monsters, weapons, etc.

| WAD              | Maps | Mon/Lvl | Checks | Status  | Notes |
| ---------------- | ---- | ------- | ------ | ------- | ----- |
| [1000 Lines]     |   32 |     137 |    458 | basic   | Does not include the two bonus levels. |
| [1000 Lines II]  |   32 |     116 |    415 | basic   | |
| [Amalgoom]       |   37 |     244 |   1192 | full    | Must use [RC4](https://www.doomworld.com/forum/topic/152974-amalgoom-rc4-sandy-petersen-interview) version and the [hotfix](https://www.doomworld.com/forum/post/2965170). Details at [#53](https://github.com/ToxicFrog/doom-mods/pull/53). |
| [Demonfear]      |   32 |      39 |    336 | basic   | |
| [MAYhem 2048]    |   34 |     179 |    446 | baic    | |
| [Scythe]         |   32 |     106 |    457 | basic   | MAP26-MAP30 are much larger than the rest of the wad; consider excluding them in short sync games. |
| [Scythe 2]       |   32 |     191 |    582 | full    | |
| [Zone 300]       |   32 |      61 |    392 | partial | |

[1000 Lines]: ../../release/apworlds/zdoom_1000_lines.apworld
[1000 Lines II]: ../../release/apworlds/zdoom_1000_lines_ii.apworld
[Amalgoom]: ../../release/apworlds/zdoom_amalgoom.apworld
[Demonfear]: ../../release/apworlds/zdoom_demonfear.apworld
[MAYhem 2048]: ../../release/apworlds/zdoom_mayhem_2048.apworld
[Scythe]: ../../release/apworlds/zdoom_scythe.apworld
[Scythe 2]: ../../release/apworlds/zdoom_scythe_2.apworld
[Zone 300]: ../../release/apworlds/zdoom_zone_300.apworld


#### Standalone Games & Total Conversions

Entire games that replace most or all of the vanilla gameplay.

| Game                       | Maps | Mon/Lvl | Checks | Status  | Notes |
| -------------------------- | ---- | ------- | ------ | ------- | ----- |
| [The Adventures of Square] |   22 |     256 |    795 | problems | Not compatible with persistent mode, but otherwise complete. Checks that require explosives do not logically require Hellshells if there are TNT crates in the level. |
| Ashes 2063                 |      |         |        | missing | (1) |
| Ashes: Afterglow           |      |         |        | missing | (1) |
| Ashes: Hard Reset          |      |         |        | missing | Still need to play it. |
| Faithless Trilogy          |   28 |     156 |    440 | partial | Episode 1 fully supported. 2/3 are not yet ready for play. |
| Golden Souls Remastered    |      |         |        | missing | (3) |
| Golden Souls 2             |      |         |        | missing | (3) |
| Hedon Bloodrite            |      |         |        | missing | This is going to be a project but I think it would be pretty cool. |
| [Space Cats Saga]          |   57 |     316 |    928 | partial | Episode 1 fully tuned. Pettable cats categorized as "big-ammo" may sometimes give you weapons out-of-logic instead. |

(1) Requires progressive item support in the logic engine.
(3) Requires support for "stacking" keys that open more things the more you have.

[The Adventures of Square]: ../../release/apworlds/zdoom_the_adventures_of_square.apworld
[Space Cats Saga]: ../../release/apworlds/zdoom_space_cats_saga.apworld

### Fan-Games for Other IPs

TL;DR: might work, but will never be officially supported or included in the
apworlds.

The Archipelago project has an official policy of staying as far away as
possible from anything that even vaguely resembles trademark or copyright
infringement, and that includes randomizers that officially support fan-games.
This covers (but is not limited to) Legend of Doom, Simon's Destiny, Hocus Pocus
Doom, WolfenDoom, any of the DOSworld remakes, etc.

People are free to create their own logic and tuning files for these games, but
they will not be included in the apworld, nor linked from this repo; please
don't submit patches containing them.

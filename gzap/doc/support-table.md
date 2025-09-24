# Support Table

This file summarizes the state of support for various wads. Support is classified as:

- **basic**: the WAD has been scanned and is confirmed to generate a working game,
  but has not been playtested beyond that.
- **partial**: at least one episode's worth of levels have been played and
  the results used for logic tuning.
- **full**: all levels have been played at least once.
- **complete**: the logic is believed to be a complete and accurate reflection of the game.
- **problems**: testing has revealed that changes to the scanner, randomizer, or tuner are needed to support this properly
- **missing**: not yet supported, but I either want to add support or know people are going to ask about it.

The number of levels, monsters-per-level, and checks is given as a rough guide
to the size of the wad for the purposes of rando planning with others. The check
and monster counts assumes you are playing on UV and using the default settings;
there is usually a small amount of variation across difficulties.

The counts are also given using the default settings. Turning on more check
categories in the yaml (via `included_item_categories`) can increase this by up
to 10x (or more in some wads).

You may also want to look at the [general compatibility notes](./compatibility.md).

### IWADs

Version numbers are given so you make sure you're using the right version. If
need to identify a WAD, the [DoomWiki Resources category](https://doomwiki.org/wiki/Category:Resources)
lists all of them, with hashes. Using a different version than the one supported
here may result in glitches.

| WAD          | Maps | Mon/Lvl | Checks | Status | Notes |
| ------------ | ---- | ------- | ------ | ------ | ----- |
| Doom         |   36 |      90 | 509    | full   | v1.9ud |
| Doom 2       |   32 |     116 | 501    | full   | v1.9 |
| TNT          |   32 |     152 | 515    | basic  | v1.9 |
| Plutonia     |   32 |      95 | 427    | basic  | v1.9 |
| No Rest for the Living | 9 | 141 | 124 | full | |
| [WadFusion](https://github.com/Owlet7/wadfusion) | varies | varies | varies | missing | See https://github.com/ToxicFrog/doom-mods/pull/38 |
| Heretic      |   45 |     116 |    900 | basic  | v1.3 |
| Hexen        | | | | missing | Same concerns as Strife, plus I don't like it. |
| Strife       | | | | missing | Hub maps and complicated level scripting mean this may need changes to the generator. |
| FreeDoom     |   36 |     176 |    532 | basic | [v0.13.0](https://freedoom.github.io/download.html) |
| FreeDoom 2   |   32 |     135 |    495 | basic | [v0.13.0](https://freedoom.github.io/download.html) |
| Chex Quest 3 |   15 |      83 |    196 | complete | [v1.4](https://www.chexquest3.com/downloads/); v2.0-prerelease is not yet supported. |

### PWADs

| WAD              | Maps | Mon/Lvl | Checks | Status | Notes |
| ---------------- | ---- | ------- | ------ | ------ | ----- |
| 1000 Lines       |   32 |     137 | 397 | full | Does not include the two bonus levels. |
| 1000 Lines II    |   32 |     116 | 469 | full | |
| Amalgoom         |   37 |     244 | 972 | full | Must use [RC4](https://www.doomworld.com/forum/topic/152974-amalgoom-rc4-sandy-petersen-interview) version and the [hotfix](https://www.doomworld.com/forum/post/2965170). Details at [#53](https://github.com/ToxicFrog/doom-mods/pull/53). |
| Demonfear        |   32 |      39 | 289 | full | |
| Going Down Turbo |   32 |     163 | 450 | partial | |
| Master Levels for Doom II | 21 | 120 | 401 | full | |
| MAYhem 2048      |   34 |     179 | 384 | partial | Would be full, but I accidentally overwrote half the tuning data. |
| Scythe           |   32 |     106 | 405 | full | MAP26-MAP30 are much larger than the rest of the wad; consider excluding them in short sync games. |
| Scythe 2         |   32 |     191 | 477 | full | |

### Standalone Games & Total Conversions

| Game                     | Maps | Mon/Lvl | Checks | Status | Notes |
| ------------------------ | ---- | ------- | ------ | ------ | ----- |
| The Adventures of Square | 22 | 256 | 640 | partial | Not compatible with persistent mode. |
| Ashes 2063               | | | | missing | |
| Ashes: Afterglow         | | | | missing | Uses hub maps. |
| Ashes: Hard Reset        | | | | missing | Still need to play it. |
| Faithless Trilogy        | | | | missing | Requires manual work to handle ACS-defined portals. |
| Golden Souls Remastered  | | | | missing | |
| Golden Souls 2           | | | | missing | |
| Hedon Bloodrite          | | | | missing | This is going to be a project but I think it would be pretty cool. |
| Space Cats Saga          | 57 | 316 | 1042 | partial | Pettable cats categorized as "big-ammo" may sometimes give you weapons out-of-logic instead. |

### Fan-Games for Other IPs

TL;DR: might work, but will never be officially supported or included in the
apworld.

The Archipelago project has an official policy of staying as far away as possible
from anything that even vaguely resembles trademark or copyright infringement,
and that includes randomizers that officially support fan-games. This includes
(but is not limited to) Legend of Doom, Simon's Destiny, Hocus Pocus Doom,
WolfenDoom, any of the DOSworld remakes, etc.

People are free to create their own logic and tuning files for these games, but
they will not be included in the apworld, nor linked from this repo; please don't
submit patches containing them.

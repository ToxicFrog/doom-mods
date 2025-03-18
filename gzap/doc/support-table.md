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

The number of checks and levels is given as a rough guide to the size of the wad
for the purposes of rando planning with others. Check count is for UV; other
difficulty levels might have slightly more or less.

### IWADs

| WAD | Maps | Checks | Status | Notes |
| --- | ---- | ------ | ------ | ----- |
| Doom | 36 | 509 | basic | |
| Doom 2 | 32 | 501 | basic | |
| TNT | 32 | 515 | basic | |
| Plutonia | 32 | 427 | basic | |
| WadFusion | varies | varies | missing | |
| Heretic | 45 | 1208 | basic | |
| Hexen | | | missing | Same concerns as Strife, plus I don't like it. |
| Strife | | | missing | Hub maps and complicated level scripting mean this may need changes to the generator. |
| FreeDoom | 36 | 532 | basic | |
| FreeDoom 2 | 32 | 495 | basic | |
| Chex Quest 3 | 15 | 196 | complete | |

### PWADs

| WAD | Maps | Checks | Status | Notes |
| --- | ---- | ------ | ------ | ----- |
| 1000 Lines | 32 | 397 | full | Does not include the two bonus levels. |
| Demonfear | 32 | 289 | full | |
| Going Down Turbo | 32 | 450 | problems | Some levels have intentionally-unreachable items in them, which need to be excluded from randomization. Known issues with persistent mode. |
| MAYhem 2048 | 34 | 384 | partial | Would be full, but I accidentally overwrote half the tuning data. |
| Scythe | 32 | 405 | full | MAP26-MAP30 are much larger than the rest of the wad; consider excluding them in short sync games. |

### Standalone Games

| Game | Status | Notes |
| ---- | ------ | ----- |
| Adventures of Square | missing | Requires scanner improvements to handle AOS weapons. |
| Ashes 2063 | missing | |
| Ashes: Afterglow | missing | Uses hub maps. |
| Ashes: Hard Reset | missing | Still need to play it. |
| Faithless Trilogy | missing | Requires manual work to handle ACS-defined portals. |
| Hedon Bloodrite | missing | This is going to be a project but I think it would be pretty cool. |

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

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

### IWADs

| WAD | Status | Notes |
| --- | ------ | ----- |
| Doom | basic | |
| Doom 2 | basic | |
| TNT | basic | |
| Plutonia | basic | |
| WadSmoosh | missing | |
| Heretic | basic | |
| Hexen | missing | Same concerns as Strife, plus I don't like it. |
| Strife | missing | Hub maps and complicated level scripting mean this may need changes to the generator. |
| FreeDoom | basic | |
| FreeDoom 2 | basic | |
| Chex Quest 3 | complete | |

### PWADs

| WAD | Status | Notes |
| --- | ------ | ----- |
| Demonfear | full | |
| Going Down Turbo | problems | Some levels have intentionally-unreachable items in them, which need to be excluded from randomization. |
| MAYhem 2048 | partial | Would be full, but I accidentally overwrote half the tuning data. |
| Scythe | full | |

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

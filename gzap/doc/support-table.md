
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
- **full**: tuning data is present for all levels and all default-randomized
  items. Other items (e.g. small/medium health and ammo) may lack tuning.
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

Secrets are off by default; the `+secret` column lists the total number of
checks with secrets on but settings otherwise at defaults.

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

| WAD                              | Maps | Mon/Lvl | Checks | +secret |   Status | Notes |
| -------------------------------- | ---- | ------- | ------ | ------- | -------- | ----- |
| [Chex Quest 3]                   |   15 |      83 |    145 |     229 | complete | [v1.4](https://www.chexquest3.com/downloads/); v2.0-prerelease is not yet supported. |
| [Doom]                           |   36 |      90 |    394 |     629 | complete | Ultimate Doom v1.9ud |
| [Doom 2]                         |   32 |     116 |    392 |     616 | full     | v1.9 |
| [FreeDoom]                       |   36 |     176 |    404 |     694 | basic    | [v0.13.0](https://freedoom.github.io/download.html) |
| [FreeDoom 2]                     |   32 |     135 |    405 |     653 | full     | [v0.13.0](https://freedoom.github.io/download.html) -- tuning only covers UV but is complete for that difficulty. |
| [Heretic]                        |   45 |     116 |    556 |     832 | basic    | Shadow of the Serpent Riders v1.3 |
| Hexen                            |      |         |        |         | missing  | Someone else is working on the logic for this. |
| [Legacy of Rust]                 |   15 |     215 |    219 |     351 | problems | Fully tuned, but MAP14 is excluded until [this feature](https://github.com/UZDoom/UZDoom/issues/184) is implemented. |
| [Master Levels for Doom II]      |   21 |     120 |    362 |     452 | full     | |
| [No Rest for the Living]         |    9 |     141 |    103 |     195 | full     | |
| [Plutonia]                       |   32 |      95 |    346 |     484 | full     | v1.9 |
| [SIGIL]                          |    9 |      91 |     87 |     149 | complete | [v1.23](https://romero.com/s/SIGIL_V1_23-8fh4.zip) Fully featured with use of regions.|
| SIGIL II                         |      |         |        |         | missing  | |
| Strife                           |      |         |        |         | missing  | |
| [TNT]                            |   32 |     152 |    436 |     619 | basic    | |
| WadFusion                        |varies|  varies | varies |  varies | missing  | A [tool](https://github.com/Owlet7/wadfusion) for combining official WADs into one game. See https://github.com/ToxicFrog/doom-mods/pull/38 for progress of support. |

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
[Sigil]: ../../release/apworlds/zdoom_sigil.apworld
[TNT]: ../../release/apworlds/zdoom_tnt.apworld

### Featured WADs

These are WADs available throught Night Dive's
[Featured Mods List](https://doomwiki.org/wiki/Featured_mods) in the
`Doom + Doom II` launcher.

| WAD                              | Maps | Mon/Lvl | Checks | +secret |   Status | Notes |
| -------------------------------- | ---- | ------- | ------ | ------- | -------- | ----- |
| [Arrival]                        |   11 |     250 |    270 |     306 | basic    | |
| Anomaly Report                   |      |         |        |         | missing  | |
| [Base Ganymede]                  |   27 |     149 |    276 |     325 | basic    | |
| [BTSX E1]                        |   23 |     254 |    447 |     574 | complete | |
| BTSX Episode 2                   |      |         |        |         | missing  | |
| [Deathless]                      |   36 |      65 |    278 |     416 | basic    | |
| Doom Zero                        |      |         |        |         | missing  | |
| Double Impact                    |      |         |        |         | missing  | |
| Earthless: Prelude               |      |         |        |         | missing  | |
| Going Down                       |      |         |        |         | missing  | |
| [Going Down Turbo]               |   32 |     163 |    425 |     474 | partial  | |
| Harmony                          |      |         |        |         | missing  | |
| No End In Sight                  |      |         |        |         | missing  | |
| REKKR                            |      |         |        |         | missing  | |
| Revolution!                      |      |         |        |         | missing  | |
| [Scientist]                      |   20 |     118 |    237 |     346 | basic    | |
| Syringe                          |      |         |        |         | missing  | |
| Tetanus                          |      |         |        |         | missing  | |
| Trooper's Playground             |      |         |        |         | missing  | |

[Arrival]: ../../release/apworlds/zdoom_arrival.apworld
[Base Ganymede]: ../../release/apworlds/zdoom_base_ganymede.apworld
[BTSX E1]: ../../release/apworlds/zdoom_btsx_e1.apworld
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

| WAD                              | Maps | Mon/Lvl | Checks | +secret |   Status | Notes |
| -------------------------------- | ---- | ------- | ------ | ------- | -------- | ----- |
| [1000 Lines]                     |   32 |     137 |    327 |     437 | basic    | Does not include the two bonus levels. |
| [1000 Lines II]                  |   30 |     151 |    315 |     396 | basic    | |
| [Amalgoom]                       |   37 |     244 |    848 |    1191 | full     | Must use [RC4](https://www.doomworld.com/forum/topic/152974-amalgoom-rc4-sandy-petersen-interview) version and the [hotfix](https://www.doomworld.com/forum/post/2965170). Details at [#53](https://github.com/ToxicFrog/doom-mods/pull/53). |
| [Demonfear]                      |   32 |      39 |    271 |     335 | complete | |
| [Eviternity]                     |   32 |     297 |    592 |     771 | complete | |
| [Eviternity II]                  |   36 |     470 |    724 |     920 | complete | |
| [MAYhem 2048]                    |   34 |     179 |    307 |     416 | basic    | |
| [Overboard]                      |   13 |     290 |    222 |     253 | complete | |
| [Scythe]                         |   32 |     106 |    363 |     468 | basic    | MAP26-MAP30 are much larger than the rest of the wad; consider excluding them in short sync games. |
| [Scythe 2]                       |   32 |     191 |    478 |     604 | full     | |
| [Zone 300]                       |   32 |      61 |    252 |     360 | partial  | |

[1000 Lines]: ../../release/apworlds/zdoom_1000_lines.apworld
[1000 Lines II]: ../../release/apworlds/zdoom_1000_lines_ii.apworld
[Amalgoom]: ../../release/apworlds/zdoom_amalgoom.apworld
[Demonfear]: ../../release/apworlds/zdoom_demonfear.apworld
[Eviternity]: ../../release/apworlds/zdoom_eviternity.apworld
[Eviternity II]: ../../release/apworlds/zdoom_eviternity_ii.apworld
[MAYhem 2048]: ../../release/apworlds/zdoom_mayhem_2048.apworld
[Overboard]: ../../release/apworlds/zdoom_overboard.apworld
[Scythe]: ../../release/apworlds/zdoom_scythe.apworld
[Scythe 2]: ../../release/apworlds/zdoom_scythe_2.apworld
[Zone 300]: ../../release/apworlds/zdoom_zone_300.apworld


#### Standalone Games & Total Conversions

Entire games that replace most or all of the vanilla gameplay.

| Game                             | Maps | Mon/Lvl | Checks | +secret |   Status | Notes |
| -------------------------------- | ---- | ------- | ------ | ------- | -------- | ----- |
| [The Adventures of Square]       |   22 |     256 |    589 |     793 | problems | Not compatible with persistent mode, but otherwise complete. Checks that require explosives can be reached with either the hellshell launcher or TNT crates. |
| Ashes 2063                       |      |         |        |         | missing  | (1) |
| Ashes: Afterglow                 |      |         |        |         | missing  | (1) |
| Ashes: Hard Reset                |      |         |        |         | missing  | Still need to play it. |
| [Faithless]                      |   19 |     168 |    160 |     261 | partial  | Episodes 1 and 2 have complete support. Logic development is ongoing for episode 3. |
| Golden Souls Remastered          |      |         |        |         | missing | (3) |
| Golden Souls 2                   |      |         |        |         | missing | (3) |
| Hedon Bloodrite                  |   22 |     205 |   1273 |    1404 | missing | This is going to be a project but I think it would be pretty cool. |
| [Space Cats Saga]                |   40 |     433 |    794 |     896 | partial  | Episode 1 has complete logic, other episodes only basic. Checks that replace pettable cats may sometimes require noclipping to touch even if they look reachable. |
| [Time Tripper]                   |    9 |      88 |     66 |      87 | complete | |

(1) Requires progressive item support in the logic engine.
(3) Requires support for "stacking" keys that open more things the more you have.

[The Adventures of Square]: ../../release/apworlds/zdoom_the_adventures_of_square.apworld
[Faithless]: ../../release/apworlds/zdoom_faithless.apworld
[Space Cats Saga]: ../../release/apworlds/zdoom_space_cats_saga.apworld
[Time Tripper]: ../../release/apworlds/time_tripper.apworld

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

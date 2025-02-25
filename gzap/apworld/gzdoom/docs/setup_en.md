# gzArchipelago Setup

This is a quick reference document; the full documentation can be found
[here](https://github.com/ToxicFrog/doom-mods/blob/main/gzap/README.md), including the
[setup and play instructions](https://github.com/ToxicFrog/doom-mods/blob/main/gzap/doc/gameplay.md) and the
[supported WAD list](https://github.com/ToxicFrog/doom-mods/blob/main/gzap/doc/support-table.md).


## Required Software

- [gzArchipelago](https://github.com/ToxicFrog/doom-mods/releases)
  - Hosts only need the apworld (and nothing else on this list)
  - Players need the `gzArchipelago.pk3` as well
- [gzDoom](https://zdoom.org/downloads)
- A copy of [Doom 1/2](https://www.gog.com/en/game/doom_doom_ii) or
  [Heretic](https://www.gog.com/en/game/heretic_hexen_collection) depending on
  what WAD you want to play
  - These links are to the GOG version, but any version will work as long as it
    includes `doom.wad`, `doom2.wad`, or `heretic.wad`
  - You can also use [FreeDoom](https://freedoom.github.io/download.html) to play Doom 1/2 WADs (or themselves)
- A launcher like [DoomRunner](https://github.com/Youda008/DoomRunner) is optional but highly recommended
- If you want to play a WAD that isn't one of the base games, you will also need that WAD


## Quick Setup

- Install the apworld
- Add the pk3 to your load order wherever
- Generate the game as normal
- Archipelago will emit a pk3; add it to your load order **at the end**
- **Singleplayer**: just start the game and play
- **Multiplayer**: start `GZDoom Client` from the Archipelago launcher; it will
  tell you what options to launch the game with


## Randomizer behaviour

### Item pool

Weapons, keys, powerups, and backpacks are replaced with checks and added to the
item pool. The pool also contains an access code for each level and a computer
map for each level.

Level unlocks, keys, and weapons are considered progression items. Maps are useful
items. Everything else is filler.

### Win condition

You win by beating every level. Note that a level might not be completable as soon
as it's unlocked -- the logic may expect you to duck into it, grab a few checks,
and then come back and finish it later.



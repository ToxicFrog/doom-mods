# Quick Setup

This document is a brief outline of what you need to play, for players who are
already familiar with the AP and UZ ecosystems. If that doesn't describe you,
you are probably looking for the [detailed setup guide](./setup.md).

- Install [uzdoom.apworld](../../release/uzdoom.apworld)
- Install [addon apworlds](./support-table.md) for your intended WADs
- Generate your YAML templates as normal
  - They will show up as `UZDoom (Wad Name).yaml`
- Generate your game
  - If using the web host: use `Download patch file` to get a game-specific PK3
  - If self-hosting: get the PK3 from the generated `AP_1234.zip`
  - It will be named similar to `AP_1234_P0_PlayerName.WadName.pk3`
- Set up your load order:
  - IWAD
  - PWAD containing the maps you're playing, if separate
  - any other PWADs you want to use, like weapon/enemy/hud replacers
  - `UZArchipelago.pk3`
  - `AP_1234_P0_PlayerName.WadName.pk3`
- If playing **singleplayer**:
  - Go ahead and start UZDoom
- If playing **multiworld**:
  - Start `UZDoom Client` from the Archipelago launcher
  - Copy the command line arguments it tells you to use over to UZDoom
  - Start UZDoom using those options and begin a new game, and the client will
    autoconnect once the first map loads


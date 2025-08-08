# gzArchipelago

This is an implementation of
[Archipelago Multiworld Randomizer](https://archipelago.gg/)
support for gzDoom.

Features include:
- uses zScript and a separate client program to work without modifying gzDoom itself
- supports single-player, multiplayer synchronous, and multiplayer async play
- autoscan feature for quickly importing new wads
- autotune feature for automatically improving wad support based on play
- broad compatibility with both cosmetic and gameplay mods

You can download the latest stable release from the
[release page](https://github.com/ToxicFrog/doom-mods/releases/tag/gzap-0.3.1),
or try the development versions of the [mod](../releases/gzArchipelago-latest.pk3)
and [apworld](../releases/gzdoom.apworld).

The documentation is split into multiple files.

If you just want to **play a supported wad**:
- [Setup](./doc/setup.md)
- [Gameplay](./doc/gameplay.md)
- [Supported WAD List](./doc/support-table.md)
- [FAQ](./doc/faq.md)

If you want to **import a new wad**, or **improve support for an existing one**:
- [Importing and Tuning Wads](./doc/new-wads.md)
- [General Compatibility Notes](./doc/compatibility.md)

If you want to **study or modify this mod**:
- [Glossary of Terms](./doc/glossary.md)
- [Randomizer Logic Description](./doc/logic.md)
- [IPC Protocol Documentation](./doc/protocol.md)

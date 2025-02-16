# gzArchipelago

This is a mod and set of tools implementing [Archipelago](https://archipelago.gg/)
multiworld randomizer support for gzDoom.

Features include:
- works with vanilla gzDoom using a mod and separate client program
- supports single-world play without using the client
- autoscan feature for easily importing new wads
- autorefine feature for easily improving existing wad support
- compatible with most cosmetic and some gameplay mods

Most of the documentation is split up into separate files, covering different
topics. If you just want to play the game, you probably want the
[setup and play documentation](./doc/gameplay.md). You might also want to look
at the [compatibility notes](./doc/compatibility.md) if you plan to play a
non-vanilla WAD or use gameplay mods. If you have more questions about features,
or what the point of this project is in general, consider the [FAQ](./doc/faq.md).

If you want to play a WAD that isn't already supported, or you want to improve
existing support for a WAD, see [importing new WADs](./doc/new-wads.md).

Finally, if you plan to look at the internals of gzArchipelago, I recommend
consulting the [glossary](./doc/glossary.md),
[randomizer logic description](./doc/logic.md), and
[IPC protocol documentation](./doc/protocol.md).

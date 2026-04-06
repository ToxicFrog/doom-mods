# UZArchipelago

This is an implementation of [Archipelago Multiworld Randomizer](https://archipelago.gg/)
support for UZDoom. (It also supports GZDoom, although it is likely to stop
working at some point; LZDoom and legacy ZDoom are not supported.)

Features include:
- uses zScript and a separate client program to work without modifying UZDoom itself
- supports single-player, multiplayer synchronous, and multiplayer async play
- autoscan feature for quickly importing new wads
- autotune feature for automatically improving wad support based on play
- broad compatibility with both cosmetic and gameplay mods


## Downloads

To play, you will need three downloads:
- the *shared apworld* (`uzdoom.apworld`) which contains generic uzdoom support;
- the *game mod* (`UZArchipelago.pk3`) which is loaded by the game; and
- a *logic pack apworld* for the specific WAD you want to play.

Note that you cannot mix stable and unstable apworlds/mods -- make sure that you
are downloading the same version for everything!

### Stable Release

The latest **stable release** is available from the
[github releases page](https://github.com/ToxicFrog/doom-mods/releases?q=UZArchipelago&expanded=true).
The release has links to the shared apworld and game mod, and a link to the list
of logic packs supported by that version, from which you can download the logic
packs themselves.

### Unstable Release

The **unstable release** receives new features before they appear in stable, but
also receives less testing, and routinely breaks compatibility with yamls, logic
packs, and generated games from the stable version.

You can download it here:
- [shared apworld](../release/uzdoom.apworld)
- [game mod](../release/UZArchipelago-latest.pk3)
- [logic packs](./doc/support-table.md)

For a list of changes in unstable that are not yet available in a stable
release, see the `Unreleased` section of the [changelog](./CHANGELOG.md).

## Documentation

The documentation is split into multiple files.

If you just want to **play a supported wad**:
- [Setup](./doc/setup.md)
- [Gameplay](./doc/gameplay.md)
- [Supported WAD List](./doc/support-table.md)
- [FAQ](./doc/faq.md)
- [Glossary of Terms](./doc/glossary.md)

If you want to **import a new wad**, or **improve support for an existing one**:
- [Importing and Tuning Wads](./doc/new-wads.md)
- [General Compatibility Notes](./doc/compatibility.md)

If you want to **study or modify this mod**:
- [Glossary of Terms](./doc/glossary.md)
- [Randomizer Logic Description](./doc/logic.md)
- [IPC Protocol Documentation](./doc/protocol.md)

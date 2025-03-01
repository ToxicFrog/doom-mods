# 0.2.0

This is a feature release.

⚠️ The logic file format has changed. v0.1 logic files are not compatible.

- New:
  - Support for scanning DEHACKED-modified pickups.
  - Logic and tuning for Chex Quest 3 [by @frozenLake]
  - Tuning for Doom 1 E1 [by @ChrisCJ]
  - Configurable limits for the item bank
  - Configurable limits for how many copies of each weapon go into the item pool
  - Partial tuning of the first few Doom 2 levels should mean it's less eager to
    send you to Dead Simple all the time
  - Support for levelport specials in the scanner, as used in e.g. Faithless
    and Hexen. EXPERIMENTAL, and does not imply support for those wads.
  - Logic and partial tuning for Scythe
- Change:
  - AP client is now called "GZDoom Client" rather than "Text Client"
  - A message displays in gzDoom when the connection to AP is established
- Fix:
  - Crash on game startup in certain rando configurations that exclude levels
  - gzdoom launch arguments emitted by client are now copy-pasteable even in
    the GUI
  - Command line flags reported by the client should hopefully work on Windows
  - Crash when loading tuning files that contained certain messages
  - Collected checks could respawn as their original items when revisiting a level
  - `useplayerstartz` flag support in `MAPINFO` (fixes Alfonzone, among others)
  - Potential wrongness when generating games on ITYTD or NM! difficulty
  - Unreachable item in MAP07 now properly marked as such
  - Level difficulty is now inferred from how far away that level is from any
    starting map, rather than its index in the WAD. In particular this means
    that episode starts are now correctly guessed as easier than episode bosses.

# 0.1.0

Initial release of gzArchipelago.


# Unreleased

⚠️ The IPC structure has changed. Double check the `gzdoom` command line options
that Archipelago tells you and update your launcher config or shell scripts.

- New:
  - Animated icons for progression and unreachable checks
  - "No secret progression items" option
  - Request hints from the level select screen with →
  - Received hints for your items are displayed on the level select screen
  - Received hints for the contents of your locations likewise
  - Tuning for FreeDoom 2 [by @frozenLake]
  - Tuning now understands any-of access requirements, so it is possible to
    express things like "this check requires either the red key or the blue key"
  - YAML option to disable respawning on death, and require resuming from a savegame
  - YAML option to make all levels persistent
  - In-game option to suppress weapon drops from enemies. Suppressed weapons will
    be replaced with the same quantity of ammo you would have gotten from them.
  - Warning displayed on game entry if the WAD or difficulty don't match the
    YAML settings.
- Change:
  - Improvements to Scythe logic
  - GZD<->AP interact files are now stored in `$AP/gzdoom`, which has multiple
    subdirectories
  - `$GZAP_EXTRA_LOGIC` envar removed
  - External logic files can now be placed in `$AP/gzdoom/logic` and
    `$AP/gzdoom/tuning` and will be loaded automatically
  - The event handlers needed for gameplay are not loaded when only scanning
  - `skill` yaml setting replaced with `spawn_filter`. The difficulty selection
    in-game now actually functions again.
- Fix:
  - If an item bank limit was exceeded while you were between levels, the excess
    items would vanish. You will now receive them when you next enter a level.
  - Tuning was not properly modeling locations reachable with some, but not all,
    keys, resulting in them being considered completely inaccessible.
  - `ap_scan_unreachable 2` was not triggering when you exited the level via the
    level select menu.
  - With persistence on, levels were sometimes not properly registered as complete.
  - The AP client could end up processing leftover messages from a previous game
    when first started.
  - Collecting a check in multiplayer while disconnected from the server could
    result in it getting lost forever.

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


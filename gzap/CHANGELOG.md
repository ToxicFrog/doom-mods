# Unreleased

This is a bugfix release.

- Change:
  - Inventory is now sorted alphabetically.
- Fix:
  - Crash in client when receiving a message from the server with no `type` field.

# 0.3.3

This is a bugfix release.

This release changes the map scanner. It is recommended that you rescan your wads,
although old logic files will continue to work.

This release changes the APWorld options. Please regenerate the template YAML.

- New:
  - `pretuning_mode` option for doing a tuning run without randomizing item
    placements or giving the player any starting keys.
  - Collected check translucency is adjustable via the `ap_collected_alpha`
    cvar. Setting takes effect on level entry.
  - Logic and tuning for 1000 Lines.
  - Support for a `GZAPRC` lump for per-wad scanner configuration. See the
    [Adding New WADs](doc/new-wads.md) documentation for details.
  - `included_item_category` option to control which items are included in the
    rando. This is work in progress and is planned to be expanded later, but
    what is there should work.
  - Logic and tuning for Adventures of Square [by @frozenLake]
- Change:
  - default `included_levels` value is now `[]` rather than a list of every level
    in every supported wad; the behaviour is the same, but it was getting a bit
    unwieldy.
  - generated PK3 file now includes the selected wad name in the filename, e.g.
    `AP_1234_P1_ToxicFrog.Doom_2.pk3`.
- Fix:
  - In-game timer now counts only time spent in gameplay, not time in menus.
  - In-game timer should no longer double-count gameplay time.
  - APWorld has better error reporting for certain classes of generation errors.
  - Returning to a level where you've previously found some checks will report
    them as collected items, rather than reducing the total item count for that
    level.
  - Keys were not always properly added or removed when returning to earlier
    levels with persistence enabled.
  - Command line arguments emitted by the client for launching gzdoom with now
    always use forward slashes, to avoid escaping issues on windows.
  - HealthPickups are now properly scanned as health, not tools. In particular
    this means that Quartz Flasks no longer flood the item pool in Heretic.
    (Mystic Urns are still included in the pool.)
  - +INVBAR items that don't fall into any other category are now properly
    scanned as tools. This has no effect at present but will be important for
    some TCs later.
  - Scanner now uses the same logic to merge nearby locations as the check
    replacer does, which should improve scanning of levels where items are placed
    on conveyor belts or elevators.

# 0.3.2

This is a bugfix release.

This release changes the map scanner. Existing logic files don't need to be
regenerated, but if the WAD they were generated from uses compatibility flags,
it is recommended that you do so.

- New:
  - Some alternate Firemace spawn locations added to Heretic logic.
  - Collected checks will ghost out in the world rather than disappearing. (They
    will still vanish from the automap, for now.)
- Fix:
  - Checks are no longer destroyable by crushers.
  - Support for many more MAPINFO flags, most of them `compat_` flags used to
    re-enable various bugs that some maps require. GZD automatically enables
    these flags as needed for the original IWADs, but this fixes issues with
    some PWADs as well as Wadfusion.
  - Fix for generation failures in wads where certain keys only exist on some
    difficulties, first reported on DIY.WAD. As a workaround, the keys will
    appear on all difficulties rather than just the ones they were originally
    specified for.
  - The logic/tuning parser will now report the line number and offending line
    when it fails to parse a line.
  - The logic scanner now forces a newline before emitting a map block, as a
    workaround for some IPK3s that emit garbage into the log without trailing
    newlines.

# 0.3.1

This is a bugfix release.

- Fix:
  - Records of which locations have been checked were not always properly sent
    to gzdoom from AP.
  - Weapon drop suppression did not properly handle `WeaponGiver`s.
  - Receiving weapons from AP did not always work.
  - Moving from a level where you have a key to one where you don't need that key
    could leave the key in your inventory (which didn't affect anything but did
    look untidy).

# 0.3.0

⚠️ The IPC structure has changed. Double check the `gzdoom` command line options
that Archipelago tells you and update your launcher config or shell scripts.

- New:
  - Animated icons for progression and unreachable checks
  - Integrated hint support (multiplayer only):
    - Request hints from the level select screen with →
    - Received hints for your items are displayed on the level select screen
    - Received hints for the contents of your locations likewise
  - YAML options:
    - Don't place progression items in secrets
    - Disable respawn on death, require resuming from save instead
    - Make all levels persistent as if they were connected to a hub
  - In-game option to suppress weapon drops from enemies. Suppressed weapons will
    be replaced with the same quantity of ammo you would have gotten from them.
  - Tuning for FreeDoom 2 [by @frozenLake]
  - Tuning now understands any-of access requirements, so it is possible to
    express things like "this check requires either the red key or the blue key"
  - Warning displayed on game entry if the WAD or difficulty don't match the
    YAML settings.
- Change:
  - Improvements to Scythe logic
  - GZD<->AP interface files are now stored in `$AP/gzdoom`, which has multiple
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
  - The code for loading tuning files did not properly handle locations accessible
    with some, but not all, keys. (The files themselves are fine.)
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


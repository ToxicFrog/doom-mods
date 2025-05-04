# Unreleased

This is a bugfix release.

This release changes the scanner, but only wads that use the `specialaction_lowerfloortohighest`
level special need to be rescanned. (It also affects wads that use hubclusters,
but those are not yet supported in general.)

- New:
  - Tuning data for Plutonia [from @Gwen].
  - Partial tuning (22 maps, major items only) for Going Down Turbo.
  - `ap-debug` netevent to dump the AP state to the console.
  - Keys are now displayed in the inventory menu, and can be toggled on and off
    (once you have them) for tuning purposes. Infelicitous use of this feature
    can create impossible logic, so please be careful.
- Change:
  - Going Down Turbo logic updated from RC 1.7 to the version released on idgames.
  - Scanner now automatically skips levels with no randomizeable actors in them.
  - Unreachable checks are now placed next to the item they would otherwise have
    replaced, rather than replacing it.
  - In pretuning mode, all items picked up will be immediately vended, the same
    as normal Doom gameplay; the AP inventory is bypassed.
- Fix:
  - Incorrectly formatted `ap_bank_custom` entries will now be skipped instead
    of crashing the game.
  - Scanner now properly handles `specialaction_lowerfloortohighest`. Heretic
    logic updated accordingly.
  - `ap_scan_skip` setting did not behave properly when `ap_scan_recurse` was
    enabled.
  - Scan data for levels is no longer retained in memory once the level logic
    is output. This should improve performance and memory usage when scanning
    very large wads.
  - If you pick up a key that wasn't detected by the scanner (e.g. dropped by an
    enemy or spawned with zscript or ACS), it will now be properly detected and
    will be restored to your inventory when you return to that level.
  - `1000 Lines II` logic was accidentally a duplicate of the `Doom 2` logic.
  - When scanning hubcluster levels, it will bounce between the level being
    scanned and the `GZAPHUB` to force a reset. This may result in an excessive
    number of intermission screens being displayed, unfortunately.
  - Item or location names from other games with quotes or backslashes in them
    should no longer crash gzdoom on startup.

# 0.4.3

This is primarily a bugfix release, but also comes with [Universal Tracker](https://github.com/FarisTheAncient/Archipelago/releases)
support; if you have UT installed, the GZDoom Client will have a "tracker" tab,
and tracker information will be displayed in-game on the level select screen.

If you have customized the `Auto-vend patterns` setting, or found it insufficiently
useful, you should look in the options screen for the `Custom bank limits` setting
that has replaced it.

- New:
  - Runtime mod and generated mod now report the zscript version and apworld
    version, respectively, on startup. This should make version mismatches
    very obvious from the first few lines of the log.
  - Universal Tracker support. If you have UT installed, the GZDoom client will
    now have a "tracker" tab.
  - If UT is enabled, and the client is running, locations known to be in logic
    will be displayed first and hilighted on the level select screen.
  - AP inventory screen displays tooltips showing you more information about
    each item.
- Change:
  - `ap_auto_vend` setting renamed `ap_bank_custom`, now lets you configure
    bank limits per-category or per-item-type.
  - Logic loader redesigned. It now produces more useful error messages, and
    loads all internal logic files before any external ones, which should reduce
    the frequency of UT errors when joining a game while you have external logic
    files that the host doesn't.
- Fix:
  - Closing the GZDoom Client window now works even if gzdoom isn't running.
  - Certain `included_item_categories` configurations could break Universal
    Tracker.
  - Small performance improvements to AP<->GZDoom communication.
  - Quitting gzdoom now causes the client to properly realize that gzdoom has
    exited.
  - Items with different underlying types but the same user-visible name (e.g.
    Shells vs. ShellBox) were being incorrectly merged into the same item
    category.
  - Items with different underlying types but the same user-visible name now have
    the type appended to their AP name so people can tell them apart.
  - Appending types to AP names no longer causes the apworld to stop loading
    entirely when logic files requiring this are present.

# 0.4.2

This is a bugfix release.

The changes are small, but some of the bugs fixed are fairly large, including
one that was causing tuning files to not work properly, so upgrading is
recommended.

- Fix:
  - Client now forces UTF-8 encoding for file IO, which fixes a client crash on
    windows when processing messages that include non-ASCII characters.
  - Items originally placed with checks would respawn if the check was collected
    and then the level reset.
  - Checked secret sectors were not counted towards "secrets found" in the level
    stats if you left the level and then returned.
  - Tuning file entries for trivially reachable locations were not being read.

# 0.4.1

This is a bugfix release.

This release brings significant internal changes to the scanner. Rescanning wads
is not required, but is recommended; the new logic files are smaller, and it
brings better support for scanning items that are placed partly embedded in
walls/floors or on elevators/conveyors.

In a small minority of cases, rescanning a wad using 0.4.1 will cause some
tuning data generated in v0.4.0 to be invalidated. This only affects certain
UDMF-format maps, and this data will be safely skipped when the tuning file is
loaded. It does not affect tuning data from v0.3.x or earlier.

- New:
  - the `ap_scan_skip` cvar can be used to skip some levels when scanning,
    even if they are reachable from your starting levels.
  - Locations in the level select tooltips are now sorted alphabetically.
- Change:
  - `pretuning_mode` only overrides the original `MAPINFO` if you also ask for
    `full_persistence`. Leaving it off means you can now do a pretuning run with
    the original WAD's intermission screens, episode divisions, etc.
  - File extensions are now ignored when loading logic or tuning files.
  - The client now writes a separate tuning file for each game session, named
    `{wad name}.{timestamp}.tuning`.
  - Scanner and tuner now use integer positions to identify locations. In rare
    cases (on UDMF maps using fractional actor positions), this may result in
    checks being placed up to 2 world units away from the items they replaced;
    this is unlikely to be noticeable.
- Fix:
  - Scanner now captures object locations at spawn time rather than 1-2 tics
    after spawning.
  - Encountering a logic file with no maps now produces a useful error message
    rather than a division by zero crash.
  - Checks collected via release-at-exit are no longer used for tuning.
  - Map markers now properly follow checks again.
  - Check placement algorithm rewritten. "Unable to find original item, placing
    check at player" errors eliminated; checks will now always spawn in the
    correct locations.
  - "This game was generated on 'easy', but you are playing on 'easy'" error
    should no longer occur when playing on ITYTD (nor the equivalent on NM!).
  - Adventures of Square now classifies more powerup types properly.
  - Adventures of Square no longer includes cutscene maps in the logic.
  - Items weren't sorted properly in the inventory screen.

# 0.4.0

This is a feature release.

⚠️ The interface between GZDoom and Archipelago has changed. Games generated in
0.3.x are not playable with 0.4.x, nor can you play 0.4.x-generated games with
the 0.3.x mod.

⚠️ The YAML options have changed, and in particular, some options have had their
types and/or meanings changed. You must regenerate your template YAML.

⚠️ The scanner has changed. Logic files should be regenerated for the new version.
Old files will still work but some items may be mis-classified.

⚠️ The tuning file format has changed. Please remain calm. Old files remain
compatible and automatic migration is planned for a later 0.4.x version.

- New:
  - gzArchipelago now has additional data about what items were originally stored
    at check locations, and what items are stored there now, which will be used
    for future user-facing features.
  - `ap_show_check_original` setting displays what was originally that location,
    useful when learning the maps.
  - `ap_show_check_contents` setting displays the contents of each check (if it's
    a Doom item).
  - AP automaps and AP level accesses have custom icons based on FreeDoom sprites.
  - The `included_item_categories` option now lets you specify how much of each
    category to include, e.g. you can tell it to randomize 50% of powerups or
    10% of small health pickups.
  - `medium-health` and `medium-armor` categories have been added. The categorization
    of health, armour, and ammo items has been improved.
  - Logic files now include information about total monster counts and a list of
    secret sectors.
  - By adding `secret-sector` to included_item_categories, you can turn secrets
    themselves into checks; you get the check as soon as you step into the secret
    sector. Note that these are not currently marked on the map the way item-based
    checks are!
  - New option to release some or all checks in a level when you finish the level,
    for a faster-paced game that's less about check hunting and more about clearing
    maps as quickly as you can.
  - Hints are now available in singleplayer games without needing an AP server
    running! Hint limits are not enforced -- you're on the honour system.
  - The `win_conditions` option lets you specify how many levels you need to clear
    to win the game.
  - `local_weapon_bias` and `carryover_weapon_bias` options for controlling how
    early the randomizer makes weapons available to you.
- Change:
  - All logic files regenerated using the updated scanner.
  - The inventory menu no longer lists items you don't have.
  - Tuning files now include coordinate data to more reliably match in-game checks
    to locations in the logic file, even if location names change.
  - Location names have changed; if there are only a few instances of an item in
    a level, it will try to name it based on compass heading and approximate
    distance from the level center before falling back to coordinates.
- Fix:
  - Map markers were not properly displaying filler/progression status if you
    picked up the automap after entering the map when persistent mode was on.
  - Checks now vanish immediately when picked up, rather than waiting for
    confirmation from the server. (If the server never confirms they will still
    respawn when your reset the level.)
  - `ap_show_check_names` now behaves properly in netplay, and also supports
    checks that don't exist in the world.
  - Unreachable checks now contain `Health` instead of `HealthBonus` and should
    thus work with Chex Quest and other IWADs/IPK3s that don't define the latter.
  - Unreachable checks were visible on the minimap but not in play.
  - `ap_suppress_weapon_drops 3` no longer causes you to spawn without fists.
  - In-game check objects now copy the TID, thing special, and special args from
    the item they replaced, which should hopefully fix some levels that rely on
    ACS scripting when certain things are picked up.
  - `level_order_bias` now rounds to nearest rather than rounding down when
    calculating how many levels you need to beat.
  - Weapon balancing no longer counts unreachable weapons.
  - Locations with the same (X,Y) coordinates but different Z no longer cause
    generation failures.
  - Adventures of Square logic fixes.

# 0.3.5

This is a bugfix release.

- Fix:
  - Opening the level select menu when no AP-generated pk3 was loaded would crash
    the game. It now displays an error message and refuses to open.
  - The filler item pool is no longer incorrectly populated with every filler item
    the randomizer knows about (including ones that aren't being randomized) and
    thus no longer consists almost entirely of 1-point health/armour bonuses.
  - Crash in AP client on startup.

# 0.3.4

This is a bugfix release.

This release changes the APWorld options. Please regenerate the template YAML.

- New:
  - [Quickstart documentation](doc/gzdoom_newplayers.md) for players new to GZDoom
    [by @FlapjackRetro].
  - Globbing expressions are now supported in `included_levels`, `excluded_levels`,
    and `starting_levels`.
  - `start_with_keys` option can be used to turn off starting with all keys for
    the `starting_levels`.
  - `ap_auto_vend` ingame setting can force specific items or item categories to
    behave as if they had a limit of 0, useful for small-items games.
  - `ap_show_check_names` option to display the name of each check as you collect
    it.
  - `ap-use-item:<name>` netevent to allow binding hotkeys to the AP inventory.
    See [the FAQ](doc/faq.md) for more information.
- Change:
  - Inventory is now sorted alphabetically.
  - Default `starting_levels` now mimics the behaviour of apdoom by including
    the first level of every episode in D1 and Heretic.
  - Unreachable checks now contain a 1-point `HealthBonus` rather than a `Backpack`,
    both to improve compatibility with mods and to give less incentive to use
    weird speedrunning tricks to grab them anyways.
  - Unreachable checks are now greyscale rather than flashing red, to make them
    look more "boring" and less "super important".
- Fix:
  - `included_item_categories` option now supports all recognized item categories.
  - Crash in client when receiving a message from the server with no `type` field.
  - Tuning files generated by the client are now written to `AP/gzdoom/tuning/`
    like the documentation says, not `AP/gzdoom/`.
  - Scanner no longer emits invalid JSON when a map title contains a newline.
  - Known-unreachable locations are no longer listed in the "unchecked locations"
    tooltip, nor counted towards the level item total.
  - Turning off maps in `included_item_categories` no longer breaks everything.
  - Auto-vending of items will only occur if the player is in a state that will
    cause them to be picked up immediately.

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


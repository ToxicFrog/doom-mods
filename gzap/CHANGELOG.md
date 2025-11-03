# Unreleased

This is a feature/design release.

⚠️ **This update breaks backwards compatibility.** ⚠️

⚠️ Internal data structures have changed. Finish all games in progress first.

⚠️ YAML and in-game settings have changed. Generate a new template YAML and
double-check the correctness of your in-game settings.

⚠️ Logic format has changed. Existing logic may fail to load, and even if it
loads successfully, rescanning is recommended. Tuning data is unaffected.

⚠️ This update splits the apworld into three: one core apworld providing support
for the official games, plus two addon apworlds providing support for "featured
mods" and for community maps. See [support-table.md](doc/support-table.md) for
a list of which wads are in which apworld.

⚠️ This update changes how tuning loading works. If you are not a logic
developer this probably does not affect you. If you are, see [new-wads.md](doc/new-wads.md#loading-files-without-adding-them-to-the-apworld)
for details.

- New WAD support:
  - Logic and tuning for `Eviternity` and `Eviternity II`, by Akos.
  - Logic and tuning for `Legacy of Rust`, by RakeVuril.
  - Basic logic for `Arrival`, `Base Ganymede`, `Deathless`, and `Scientist`.
- New scanner and tuner features:
  - `GZAPRC` lump can now define default scanner settings for the wad.
  - `GZAPRC` lump can now define cluster names.
  - Scanner can now find maps to scan via cluster membership as well as (or
    instead of) following exits.
  - Scanner can add arbitrary tags to the logic header which can then be read by
    the apworld to adjust logic behaviour.
  - Tuner emits information about which weapons the player has and which maps
    they have visited.
  - In pretuning mode, the inventory menu lets you lie to the tuner about which
    maps you have visited if needed. ⚠️ This feature is probably getting removed
    again in favour of region prerequisite declarations.
  - Logic files can now define custom names for locations.
  - Logic and tuning files support multiline entries. If a line ends with `}` it
    is considered the end of the entry.
- New apworld features:
  - Separate `ap_gzdoom_extras.apworld` and `ap_gzdoom_featured.apworld` files.
  - Autodiscovery of addon apworlds containing gzdoom tuning/logic.
  - Items/locations can now have multiple categories, and existing categories
    have been decomposed (e.g. `big-health` items now belong to two categories,
    `big` and `health`).
  - Item/location categories, and combinations thereof, can be used in the YAML
    in any setting that supports item/location groups; see [the faq](./doc/faq.md#how-do-item-groups-work-in-the-yaml)
    for more details.
  - `included_item_categories` can now be used to force entire categories into
    starting inventory or their vanilla locations.
  - `included_item_categories` now supports keys, weapons, and AP automaps.
  - `included_item_categories` now supports specific item names as well as
    broader item categories.
- New gameplay features:
  - The inventory screen now lists all keys for the current level. Keys you do
    not yet have are hintable with `shift-H`. (This is the same mechanism as
    hinting them from the level select screen, but unlike the level select it
    lets you choose which order to hint them in.)
  - Auto-release on exit can be made conditional on having all keys for the level.
  - The inventory menu now lets you queue up multiple items and dispenses them
    all at once when closed.
- Changed:
  - The scanner now reports the display names for keys as well as the typename.
    This results in better item and location names for keys in WADs that support
    key names (i.e. not Doom 1/2).
  - Tuning data is now loaded for a wad when generation starts, rather than on
    apworld initialization. This makes apworld loading noticeably faster.
  - `allow_secret_progress` yaml option removed. Use `exclude_locations: ["secret"]`
    instead.
  - `MapRevealers` (e.g. Computer Area Map, Map Scroll) are now classified as
    `powerup` rather than as `map` for the purposes of choosing which locations
    to randomize.
  - The (poorly named) cvar `ap_scan_keys_always` was removed.
  - `start_with_all_maps` yaml option removed. Use `"ap_map:start"` in
    `included_item_categories` instead.
  - Items which are both powerups and tools, such as the Tome of Power from
    Heretic, are now classified as `powerup-tool` rather than just `powerup`.
- Fixed:
  - When running from an unpacked tarball, gzdoom now locates its files with the
    rest of the tarball contents rather than in `~/.local/share/Archipelago`.
  - Removed incorrect tuning data for `Doom` and `Doom 2`.

# 0.6.6

This is a bugfix release. It backports fixes for bugs discovered while working
on 0.7.x to the 0.6 release series.

- New:
  - If you download the pk3 for your game from the web host, the client will
    read the connection address from it and connect to AP automatically.
  - Spoiler log now includes information about which WAD was actually selected,
    not just which WADs you listed as selectable in the yaml.
- Changed:
  - Adjustments to icon guessing rules.
  - Reachable but out-of-logic locations reported by UT will now show up as
    orange in-game rather than dark grey.
  - In-game performance should now be modestly increased, especially for games
    with huge numbers of locations.
- Fix:
  - Add `map07special` flag to Master Levels for Doom II MAP20, since it was
    originally designed to go in the MAP07 slot and relies on that behaviour.
  - Fix for older python versions that don't support PEP 701 f-strings.
  - Two unreachable locations in Going Down Turbo are now properly marked as such.
  - AP client now stores found locations and re-sends them later if the connection
    to the host is interrupted.
  - Client initialization no longer fails if UT is installed and you are playing
    a wad that doesn't have any overlap with the default set of starting levels.
  - UT integration was not properly displaying tracker information in-game.

# 0.6.5

This is a bugfix release.

- New:
  - Generated pk3s now have a proper `archipelago.json` so that they can be
    downloaded from the web host.
  - Logic and tuning for Amalgoom, contributed by zapadash04.
  - Logic for Zone 300.
- Fix:
  - `MAPINFO` lump was not properly emitted when persistent mode was off.
  - Implement `get_filler_item_name()` to hopefully avoid generation failures
    when paired with apworlds that produce item pool underruns.
  - Icon inference and check location data were not always properly escaped in
    the generated zscript, leading to runtime failures when paired with some
    apworlds.
  - There is now a [compatibility patch](../release/Archipelago×FinalDoomer.pk3)
    for Final Doomer support, contributed by snackerfork.
  - Improvements to debug mode, including a crash fix for `ap-debug`.
  - Going Down Turbo logic updated for the final release version.
  - Support table entry for Plutonia corrected.

# 0.6.4

This is a bugfix release.

- Fix:
  - Level select menu entries weren't being properly redrawn if you received a
    key from another player while the menu was open, or if the server was too
    slow in acknowledging a level clear.
  - Dying with respawn off and no valid save files is no longer counted as a
    level clear.
  - If none of your `starting_levels` are available in the WAD, generation will
    fail. You can still request an empty sphere 0/1 by setting `starting_levels`
    to `[]` in multiworld games.
  - `level_order_bias` and `carryover_weapon_bias` are now computed based on
    which levels are included in the AP, rather than based on all the levels in
    the WAD. In particular this means that you can now set `level_order_bias` >0
    even if you are excluding most or all of the early levels.

# 0.6.3

This is a bugfix release.

⚠️ This update breaks compatibility with older versions of Universal Tracker.
If you have UT installed, please make sure it is version 0.2.12 or later, or
the GZDoom Client will likely crash or hang on startup.

- New:
  - Logic and tuning for `Master Levels for Doom II` [from soopercool101]
  - UT integration no longer requires you to keep the YAML for your game around;
    all needed information is loaded from the server when you connect instead.
- Change:
  - Support for recent (0.2.12+) versions of Universal Tracker.
  - If you are playing a solo game but connected to the AP client, GZAP will
    automatically turn off "singleplayer mode" and let the AP host handle checks
    and hints, which should eliminate duplicate messages for finding items and
    some other small infelicities when you are playing solo games but also using
    the client.
- Fix:
  - `gzDoom.yaml` now lists all known item categories in the template, including
    ones that are off by default.
  - Logic loader now respects skill tags on secret sectors. [from soopercool101]
  - Universal Tracker integration now uses UT callbacks rather than reading the
    tracker state directly.

# 0.6.2

This is a bugfix release.

- Change:
  - Compiled logic and tuning data is now cached in your AP directory. This uses
    a few tens of MB but also makes apworld loading about 4x faster after the
    first time.
  - Significant improvement to level select menu performance by only redrawing
    menu entries when they change. This won't make a difference in most games
    but can noticeably improve things in wads with huge numbers of checks
    and/or lots of levels.
  - Hints are now requested with `shift-H` rather than `→` to make it harder to
    request them accidentally.
  - Tuning for Episode 1 of `Space Cats Saga`.
- Fix:
  - The item icon mapper now properly detects FreeDoom 1/2 as having Doom-
    compatible spritesheets.
  - The item icon mapper now properly supports FreeDoom 1/2 weapons when you're
    playing Doom and someone else is playing FreeDoom.
  - The item icon mapper now properly supports `apdoom`/`apheretic` level access
    tokens, maps, and keys.
  - A `VERSION` file is now included in the generated pk3 to make it easier to
    debug version mismatches.
  - Item count is now correctly updated after saving, collecting some AP checks,
    and then loading the savegame.
  - Logic for `Space Cats Saga` reinstated.
  - Crash when exiting to the menu or starting a new game while a game is
    already in progress.
  - Wings of Wrath are now excluded from randomization in Heretic since they
    are often needed for in-map progression at specific locations.

# 0.6.1

This is a feature release.

- New:
  - Artwork for checks that distinguishes between progression, useful, useful
    progression, and trap, in a way that's more consistent with other apworlds,
    contributed by Vibri.
  - Traps can be disguised as filler (the default) or progression items, or
    displayed as traps.
  - Logic and tuning for No Rest for the Living [from RakeVuril].
  - Additional logic for Doom 2 [from j-palomo].
  - Logic fixes for FreeDoom E2 [from Vibri].
  - Showing check contents is now on by default.
  - When playing a Doom or Doom 2 wad, items from `apdoom` will be shown using
    their local Doom sprites. Likewise if you are playing a Heretic wad and
    someone else is playing `apheretic`.
- Change:
  - `GZAPRC` config files can now be made conditional with `require`, so that
    they are only loaded when the specific megawad they apply to is present.
  - Builtin `GZAPRC` files are now split up by game.
- Fix:
  - Disabled some debug logging that was accidentally left in 0.6.0.

# 0.6.0

This is a bugfix release. (It also has some cool new features, but the main
reason for this release -- and the reason it's 0.6.0 and not 0.5.1 -- is the
fixes to tuning generation related to keys.)

⚠️ The logic format has changed. **You must rescan your wads.** Tuning files
from earlier versions remain compatible.

- New:
  - AP keybindings are now available under `Customize Controls` as well as in
    the AP mod settings.
  - Full tuning for Doom 1 and 2 [from RakeVuril].
  - Full tuning for Scythe 2 [from wrsw].
  - Deathlink support. This is an **in-game setting** accessible from the
    gzArchipelago options menu, and defaults to off.
  - Secret-sector checks now display an AP icon on the automap (if you have
    checks on automap enabled), same as item-based checks.
  - GZAP now has a small library of builtin icons, and when generating, will try
    to guess an appropriate icon to use for items from other games, for use in-
    game when `ap_show_check_contents` is on. This library is still very sparse
    and I hope to add more icons and icon mappings in the future.
    The current icons are all from Aleksandr Makarov's Heroic Asset Series.
- Change:
  - Weapon suppression settings are now applied when the weapon is picked up,
    rather than when it is dropped.
- Fix:
  - Keys spawned during play (e.g. with scripts or via enemy drops) are now
    properly supported by the tuning engine and will be taken into account on
    future generations if the resulting tuning engine is loaded.
  - Keys spawned during play are detected instantly rather than next time you
    receive an AP item.
  - Adventures of Square E1A9 dynkeys are now properly accounted for in logic.
  - 8bpp colour is now supported when converting AP messages to display in
    gzDoom. Since, apparently, AP sometimes uses that!
  - The AP client program is now better about reporting errors.

# 0.5.0

This is a feature release.

⚠️ The YAML options have changed, and in particular, some options have had their
types and/or meanings changed. You must regenerate your template YAML.

⚠️ This release changes the scanner, but only wads that use the
`specialaction_lowerfloortohighest` level special need to be rescanned. (It also
affects wads that use hubclusters, but those are not yet supported in general.)

This is the biggest release so far, and kind of got away from me. It's mostly
bugfixes, and of the new features, most of them are small things laying the
groundwork for later improvements rather than major stuff that players will
notice. The most interesting additions, I think, are **beat specific levels as a
win condition** and **Universal Tracker glitch logic support**.

There are also many bugfixes which should improve compatibility with AutoAutoSave,
Intelligent Supplies, Adventures of Square, anything that uses a `TITLEMAP`, and
anything that uses death exits.

- New:
  - Tuning data for Plutonia [from Gwen].
  - Partial tuning (22 maps, major items only) for Going Down Turbo.
  - `ap-debug` netevent to dump the AP state to the console.
  - In pretuning mode, keys are now displayed in the inventory menu and can be
    toggled on and off, once you have them; they default off. Note that turning
    a key off after using it to reach checks can generate impossible logic, so
    please be careful.
  - `AP-KEY` messages are now emitted as part of the logic file for keys that
    exist across multiple maps. (This does not mean that hubmap-based megawads
    are now playable, but it's a step in the right direction.)
  - The client now has an icon in the AP launcher! Contributed by @DwarfWoot.
  - Universal Tracker integration now supports "glitch logic"; in UT versions
    that support this (v0.2.8 or later), locations that are out of logic due to
    weapon or difficulty settings, but which are still believed to be reachable
    otherwise, will show up with a different colour in the in-game tracker.
  - `ap_scan_prune` cvar can be used to skip levels entirely when scanning (i.e.
    not even scan them for exits).
  - New win condition: beat specific levels.
- Change:
  - Going Down Turbo logic updated from RC 1.7 to the version released on idgames.
  - Scanner now automatically skips levels with no randomizeable actors in them.
  - Unreachable checks are now placed next to the item they would otherwise have
    replaced, rather than replacing it.
  - In pretuning mode, all items picked up will be immediately vended, the same
    as normal Doom gameplay; the AP inventory is bypassed.
  - Keys are now added to your inventory by spawning them into the world and
    then touching them, similar to how other items are spawned. This should
    hopefully improve compatibility with gameplay mods that implement their own
    keys and then use `replaces` rules to replace the existing keys with them,
    rather than simply reskinning the normal Doom/Heretic keys.
  - Saving your game, collecting a check that contains a normal item (i.e. not a
    key or access token), vending the item, then loading your game now restores
    the item to your AP inventory rather than banishing it forever. This brings
    our behaviour more in line with `apquake`, and means that things like
    quicksaving, grabbing a weapon, then quickloading no longer makes that
    weapon impossible to get.
- Fix:
  - Incorrectly formatted `ap_bank_custom` entries will now be skipped instead
    of crashing the game.
  - Scanner now properly handles `specialaction_lowerfloortohighest`. Heretic
    logic updated accordingly.
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
  - Attempting to open the inventory menu when not actually playing an
    AP-randomized game now displays an error message rather than crashing, same
    as the level select menu.
  - Items counter once again properly reflects number of remaining item-based
    checks in the map.
  - `ap_scan_unreachable` is now only checked when exiting the map "properly",
    not when using the level select or loading a savegame.
  - The GZDoom<->Client connection is not initialized until you are actually
    in-game even if you are playing a mod that has a `TITLEMAP`. This fixes an
    issue where you could start the client sync while at the main menu and then
    interrupt it by loading a game.
  - Universal Tracker no longer shows `unreachable` locations (i.e. those marked
    in logic as being inaccessible by name means).
  - Universal Tracker is disabled in pretuning mode, as its output is basically
    useless when pretuning.
  - Check spawning is now smarter about what it replaces, and, in particular,
    does not replace invisible tokens. This should fix some issues with
    Intelligent Supplies and AutoAutoSave, among others.
  - Fix issues with the secret and item counts.
  - Linedef-based death exits now function properly (previously only boss-based
    death exits did). In particular this should fix Eviternity.

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


# Gun Bonsai modding documentation

This document contains information of interest to other modders, whether you want to hack on Gun Bonsai itself, re-use parts of it in your own mod, write addon mods for it, or add mod-specific compatibility tweaks.


## The BONSAIRC Lump

Gun Bonsai, on startup, loads and parses all BONSAIRC lumps available. These can be used to:

- register new upgrades (`register`)
- disable existing upgrades globally (`unregister`)
- disable specific upgrades for a given weapon or set of weapons (`disable`)
- mark a set of weapons as being the same underlying weapon (`merge`)
- override Gun Bonsai's built in weapon type inference (`type`)
- mark a weapon as a "weapon-like tool" that shouldn't earn XP (also `type`)

For an example, see Gun Bonsai's built in BONSAIRC, which applies compatibility settings for a number of mods. Mod authors who want to automatically "play nice" with Gun Bonsai can include this lump to apply mod- and weapon-specific tweaks in a non-intrusive way.


## RPC service

Integration with other mods is done via a [ZScript `Service`](https://zdoom.org/wiki/Service) named `TFLV_GunBonsaiService`. See the [implementation file](./ca.ancilla.bonsai/Service.zs) for a complete list of supported RPCs, and the `OnRegister()`, `NetworkProcess()`, and `DebugCommand()` functions in the [EventHandler](./ca.ancilla.bonsai/EventHandler.zs) and [debug library](./ca.ancilla.bonsai/debug.zs) for examples of simple usage.


## Debug commands

### Adding XP and levels

You can use netevents to add upgrades and XP using the console:

- `netevent bonsai-debug,w-up,<upgrade name> <levels>`
- `netevent bonsai-debug,p-up,<upgrade name> <levels>`
- `netevent bonsai-debug,w-xp <xp>`
- `netevent bonsai-debug,p-xp <xp>`

`levels` defaults to 1 if unspecified. The `upgrade name` must be the class name, e.g. `TFLV_Upgrade_HomingShots`; as a convenience, it understands `::` as a shorthand for the leading `TFLV_Upgrade_`, e.g. `netevent bonsai-debug,w-up,::HomingShots 5`.

The class names do not always exactly correspond to the human-readable names. Consult `LANGUAGE.en-upgrades` to find out the class names.

### Resetting your upgrades

You can fully reset the Gun Bonsai state for your character with:

- `netevent bonsai-debug,reset`

### Viewing weapon info

You can dump detailed information about Gun Bonsai's `WeaponInfo` object for the current weapon with:

- `netevent bonsai-debug,info`

### Testing save compatibility

You can add every registered upgrade to your player and current weapon with:

- `netevent bonsai-debug,allupgrades`

This will add upgrades that don't make sense for your current weapon type, mutually exclusive upgrades, character upgrades on your weapon and vice versa, etc, so no guarantees are made about the playability of the result; but doing this, tagging a nearby monster, and then saving your game is a convenient way to create a save containing every upgrade object and most elemental effects, which is convenient for checking cross-version save compatibility.

## Netevents emitted by bonsai

- `bonsai-level-up` is emitted whenever the player or their weapon gains a level. The first argument is 0 for player levels and 1 for weapon levels. The second argument is the level number.
- `bonsai-choose-level-up-option` is emitted when the player actually picks an upgrade. The first argument is -1 if they rejected the level-up and some number >= 0 if they chose an upgrade.
- Other events emitted starting with `bonsai-` or `bonsai_` are internal details not to be relied on, and are used for communication between GB's menus and the playsim.


## Building from source

The ZScript files included in this mod are not loadable as-is; they need to be preprocessed with `zspp`, which is included. The easiest way to do this is simply to run `make` and then retrieve the compiled pk3 from the `release` directory. In addition to `make` itself you will need `find` and `luajit` (for the zscript preprocessor) and the ImageMagick `convert` command (to generate the HUD textures).

You can also simply download a release pk3, unzip it, and edit the preprocessed files.


## Reusable Parts

The `GenericMenu`, `StatusDisplay`, and other menu classes are useful examples of how to do dynamic interactive menu creation in ZScript, and how to use a non-interactive OptionsMenu to create a status display.

If you want to use the option menu tooltips, look at [libtooltipmenu](../libtooltipmenu/) instead.


## Adding new Gun Bonsai upgrades

See `BaseUpgrade.zs` for detailed instructions. The short form is: you need to subclass `TFLV_Upgrade_BaseUpgrade`, override some virtual methods, and then register your new upgrade class(es) using the BONSAIRC lump.


## Fiddling with Gun Bonsai's internal state

Everything you're likely to want to interact with is stored in the `TFLV_PerPlayerStats` (held in the `PlayerPawn`'s inventory) and the `TFLV_WeaponInfo` (one per gun, stored in the PerPlayerStats). Look at the .zs files for those for details on the fields and methods available.

To get the stats, use the static `TFLV_PerPlayerStats.GetStatsFor(pawn)`. The stats are created in the `PlayerSpawned` event, so this should always succeed in normal gameplay unless something has happened to wipe the player's inventory.

Getting weapon info is slightly more complicated; `WeaponInfo` objects are created on-demand, within a tick of the weapon being wielded for the first time, so even if the player is carrying a weapon it may not have an info object. You have a number of options for getting the info object.

These are safe to call from UI code, but can return null:
- `stats.GetInfoForCurrentWeapon()` is fastest but only returns the info for the player's currently equipped weapon.
- `stats.GetInfoFor(wpn)` will get the info for an arbitrary weapon, but only if the info object already exists; it won't return info for a weapon the player has not yet wielded.

This is not UI-safe, but is more flexible:
- `stats.CreateInfoForCurrentWeapon()` is the same as `GetInfoForCurrentWeapon()` but will create the info if it doesn't exist. It can still return `null` if the player has no equipped weapon.
- `stats.GetOrCreateInfoFor(wpn)` will return existing info for `wpn` if any exists; if not, it will (if the game settings permit this) attempt to re-use an existing `WeaponInfo` for another weapon of the same type. If both of those fail it will create, register, and return a new `WeaponInfo`. Note that calling this on a `Weapon` that is not in the player's inventory will *work*, in the sense that a `WeaponInfo` will be created and returned, but isn't particularly useful unless you subsequently add the weapon to the player's inventory.

If you have an existing `WeaponInfo` and want to stick it to a new weapon, perhaps to transfer upgrades, you can do so by calling `info.Rebind(new_weapon)`. Note that this removes its association with the old weapon entirely -- the "weapon upgrades are shared by weapons of the same class" option is actually implemented by calling `Rebind()` every time the player switches weapons.

# Indestructable - an extra lives mini-mod

This mod gives you a limited number of opportunities to cheat death. When you die, if it has any charges left, you instead get a partial heal and a short-lived buff containing invincibility, time stop, and double damage.

It is highly configurable, but the default settings mimic the Death Rage mechanic (from *Duke Nukem 3D: War of Attrition*) that inspired it: 10 second duration, triggers once per level and recharges at the end of the level.

Note that some sources of damage, such as crushers, telefrags, and some types of scripted damage, can still kill you outright.

## Configuration

Indestructable's configuration settings are accessible via the in-game option screen. There, you can adjust what buffs you get when it triggers, how frequently you earn new lives, and what visual effects it uses.

## Compatibility

This mod should be compatible with almost anything; the main exception is things that rely heavily on scripted damage that bypasses defences and damage modifiers.

### Pistol Start

If you are using Universal Pistol Start or another pistol start mod, there is a setting available to control whether pistol starts also reset your lives, or if lives carry over across levels.

### Gun Bonsai

Turning on the `gun bonsai integration` option will replace the mod's normal operation with a Gun Bonsai player upgrade you can roll. See the in-game tooltips for more information.

## Mod integration

Integration with other mods is done via a [ZScript `Service`](https://zdoom.org/wiki/Service) named `TFIS_IndestructableService`. See the [implementation file](./ca.ancilla.indestructable/Service.zs) for a complete list of supported RPCs, and the `OnRegister()` and `NetworkProcess()` functions in the [EventHandler](./ca.ancilla.indestructable/EventHandler.zs) for examples of simple usage.

### The `indestructable-report-lives` netevent

If you need to automatically react to changes in the player's lifecount, you can do so via the `indestructable-report-lives` netevent, which is emitted at the same time the console message is displayed to the user, 15 tics after the number of lives changes. The first netevent argument is the absolute number of lives the player has, and the second is the delta since the last time this netevent was sent.

## Console Commands

These should not be used for mod integration (prefer the service documented above) but are available for manual debugging and cheats.

### `netevent indestructable-adjust-lives <delta> <respect_maximum>`

Used to change the number of extra lives the player has. `delta`, which can be negative, will be added to their current stock. If `respect_maximum` is nonzero, it will not add lives beyond the configured maximum (but will not take away lives the player already has).

If the player has unlimited lives, this has no effect.

### `netevent indestructable-clamp-lives <min> <max>`

If the player has fewer than `min` lives, sets them to `min`; if more than `max` lives, sets them to `max`. Passing -1 as either value will cause it to be ignored.

### `indestructable-set-lives <val>`

Sets the player's lives to `val`, ignoring all configured limits. Use `-1` to give the player unlimited lives.

## License

This is released under the same MIT license as the rest of this repo. See [COPYING.md](./COPYING.md) for details.

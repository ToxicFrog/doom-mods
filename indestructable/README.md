# Indestructable - an extra lives mini-mod

This mod gives you a limited number of opportunities to cheat death. When you die, if it has any charges left, you instead get a partial heal and a short-lived buff containing invincibility, time stop, and double damage.

It is highly configurable, but the default settings mimic the Death Rage mechanic (from *Duke Nukem 3D: War of Attrition*) that inspired it: 10 second duration, triggers once per level and recharges at the end of the level.

Note that some sources of damage, such as crushers, telefrags, and some types of scripted damage, can still kill you outright.

## Configuration

Indestructable's configuration settings are accessible via the in-game option screen. There, you can adjust what buffs you get when it triggers, how frequently you earn new lives, and what visual effects it uses.

## Mod integration

Integration with other mods is done via netevents.

### `indestructable-adjust-lives <delta> <respect_maximum>`

Used to change the number of extra lives the player has. `delta`, which can be negative, will be added to their current stock. If `respect_maximum` is nonzero, it will not add lives beyond the configured maximum (but will not take away lives the player already has).

If the player has unlimited lives, this has no effect.

The `indestructable-report-lives` event emitted afterwards will contain the actual delta between previous and current lives, which may be less than the `delta` if limits were hit.

### `indestructable-set-lives <val>`

Sets the player's lives to `val`, ignoring all configured limits. Use `-1` to give the player unlimited lives.

The `indestructable-report-lives` event emitted afterwards will contain the delta between the current and previous lives count.

### `indestructable-report-lives <lives> <delta> 0`

This is emitted every time the player gains or loses lives (whether through normal gameplay or due to an `indestructable_adjust_lives` netevent). It can be listened for by other mods to keep track of how many extra lives the player has. `delta` is the change in amount and will always be non-zero. The third argument is currently unused. Note that negative values of `lives` signify an unlimited supply.

If it is reporting a change from unlimited to limited lives, `delta` will be -9999; if a change from limited to unlimited lives, 9999.

## Compatibility

This mod should be compatible with almost anything; the main exception is things that rely heavily on scripted damage that bypasses defences and damage modifiers.

## License

This is released under the same MIT license as the rest of this repo. See [COPYING.md](./COPYING.md) for details.

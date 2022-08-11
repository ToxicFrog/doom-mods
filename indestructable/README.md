# Indestructable - an extra lives mini-mod

This mod gives you a limited number of opportunities to cheat death. When you die, if it has any charges left, you instead get a partial heal and a short-lived buff containing invincibility, time stop, and double damage.

It is highly configurable, but the default settings mimic the Death Rage mechanic (from *Duke Nukem 3D: War of Attrition*) that inspired it: 10 second duration, triggers once per level and recharges at the end of the level.

Note that some sources of damage, such as crushers, telefrags, and some types of scripted damage, can still kill you outright.

## Mod integration

Integration with other mods is done via netevents.

### `indestructable_adjust_lives <delta> <min> <max>`

Used to change the number of extra lives the player has. `delta` will be added to their current stock, which will then be clamped to be between `min` and `max`. If you don't want to apply clamping, pass -1 for those fields. Note that if the player has unlimited lives, adding or removing lives has no effect -- only the clamping will do anything.

In general this is intended to add or remove extra lives, but you can also use it to set the number to a specific value N by passing `(0, N, N)` as the arguments.

Infinite extra lives are denoted by a negative value. Since -1 is treated specially, use a different negative, e.g. `(0, -2, -2)`, to give the player infinite lives.

The `indestructable_report_lives` event emitted afterwards will contain the actual delta between previous and current lives, after clamping is taken into effect.

### `indestructable_report_lives <lives> <delta> 0`

This is emitted every time the player gains or loses lives (whether through normal gameplay or due to an `indestructable_adjust_lives` netevent). It can be listened for by other mods to keep track of how many extra lives the player has. `delta` is the change in amount and will always be non-zero. The third argument is currently unused. Note that negative values of `lives` signify an unlimited supply.

## Compatibility

This mod should be compatible with almost anything; the main exception is things that rely heavily on scripted damage that bypasses defences and damage modifiers.

## License

This is released under the same MIT license as the rest of this repo. See [COPYING.md](./COPYING.md) for details.

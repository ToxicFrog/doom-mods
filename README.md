# Laevis

Laevis is a simple gzDoom mod, with high compatibility, where your weapons grow more powerful with use.

Based on the damage you do, weapons will gain stacking damage bonuses, and once you level up enough guns you get permanent bonuses to both the damage you inflict (with every weapon) and your damage resistance.

It also has special support for [Legendoom](https://forum.zdoom.org/viewtopic.php?t=51035), allowing you to earn new effects for your Legendoom weapons by leveling them up.

All settings are configurable through the gzDoom options menu and through cvars, so you can adjust things like the level-up rate and the amount of bonus damage to suit your taste.

## Installation & Setup

Add `Laevis-<version>.pk3` to your load order. It doesn't matter where.

The first time you play, check your keybindings for "Laevis - Display Info" and, if you're using Legendoom, "Laevis - Cycle Legendoom Power" to make sure they're acceptable. You may also want to check the balance settings under "Options - Laevis Mod Options".

That's all -- if equipping a weapon and then pressing the "display info" key (default I) in game brings up the Laevis status screen, you should be good to go.

## Legendoom Integration

If you have Legendoom installed, weapons can gain new Legendoom effects on level up. Only one effect can be active at a time, but you can change effects at any time.

The total number of effects a weapon can remember depends on its rarity, from 2 (Common) to 5 (Epic). If you would gain a new effect but there's no room, you'll be prompted to choose an effect to delete.

The exception is mundane weapons (i.e. weapons that don't have a Legendoom power at all). They can earn a single Common power by leveling up, once only; if you want a different power you'll need to replace the weapon with a new one.

When using a Legendoom weapon, you can press the "Cycle Legendoom Power" key to cycle through effects, or manually select an effect from the "Laevis Info" screen.

## FAQ

### Why "Laevis"?

It's named after *Lepidobatrachus laevis*, aka the Wednesday Frog, which consumes anything smaller than itself and grows more powerful thereby.

### What IWADS/mods is this compatible with?

It should be compatible with every IWAD and pretty much every mod. It relies entirely on event handlers and runtime reflection, so as long as the player's guns are still subclasses of `Weapon` it should behave properly. It even works in commercial Doom-engine games like *Hedon Bloodrite*.

### Doesn't this significantly unbalance the game in the player's favour?

Yep! You might want to pair it with a mod like *Champions* or *Colourful Hell* to make things a bit spicier, if, unlike me, you are actually good at Doom. (Or you can pair it with *Russian Overkill*, load up Okuplok, and go nuts.)

### Aren't damage/resistance bonuses the most boring kind of upgrades?

Yes, but they're also easy to implement, and for my first Doom mod I wanted to stick to something simple. Time and energy permitting, I do want to add more interesting upgrades to it.

## Known Issues

If playing with mods that let you drop weapons, the dropped weapons will not remember their levels even once picked back up.

Mods that allow you to modify or upgrade weapons, such as DRLA, may cause the weapons to reset to level 0 when you do so.

## Future Work

This is not so much a concrete set of plans as an unordered list of ideas I've had for things I might want to add, change, and/or fix.
- Optional integration with LazyPoints and other scoredoom-style mods, so that the player score is also used as the XP counter.
- "Persistent Pistol Start" mode where weapon upgrades are remembered even once you drop the weapon; keep your upgrades across pistol starts, but you need to find the weapons again to use them.
- HUD rework; use a sprite sheet instead of DrawThickLine()
- Player bonuses other than damage/resistance, like max health, health/armour regeneration up to some level, life/armour leech, extra lives, friendly minions, etc
- Weapon bonuses other than damage, like ammo regeneration up to some level, DoTs of various kinds, exploding shots/corpses, penetrating shots, life/armour/ammo leech, etc
- Dismantle unwanted LD drops to harvest their effects
- Option to give the player XP credit for infighting

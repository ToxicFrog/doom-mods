# Laevis: a Legendoom addon

Ever played Legendoom, but wish you didn't have to choose just one of those tasty powers for each of your weapons? If so, this mod may be what you're looking for.

Laevis lets you collect a library of Legendoom powers for each weapon. Passive powers are always on; only one active power can be active at a time, but you can switch between them at will.

## Setup

Add `Laevis-<version>.pk3` to your load order. It must load after Legendoom.

If you are also using Gun Bonsai, you must use GB 0.11.0 or later; 0.10.x and earlier versions are incompatible with Laevis.

Laevis adds two new mandatory commands, which you may want to rebind:
- "Laevis: Power Menu", bound to `P` by default, displays a list of all powers your current weapon has ingested, and lets you select one
- "Laevis: Cycle Power", bound to `V` by default, switches immediately to the next power in your current weapon

## Gameplay

Initially, this plays the same as normal Legendoom. Laevis comes into play once you find your first duplicate legendary weapon. Legendoom will prevent you from picking it up without first dropping the one you already have.

Instead of doing that, look at the duplicate and press the `use` key. It will vanish and you will get a message telling you what ability your weapon just absorbed. If it was a passive ability, it will take effect immediately; if it was active, you can use the `cycle power` button (with that weapon selected) to switch between abilities, or `power menu` to view all Legendoom powers on your current weapon and pick one.

## Mod Compatibility

Laevis is an addon for Legendoom and requires Legendoom to function. It should be compatible with most mods that Legendoom itself is compatible with.

## FAQ

### Why "Laevis"?

It is named after *Lepidobatrachus laevis*, aka the Wednesday Frog, which consumes anything smaller than itself and grows larger and more powerful thereby.

### Didn't you have another mod with this name?

"Laevis" was the working title for early prototypes of my first mod, [Gun Bonsai](https://forum.zdoom.org/viewtopic.php?p=1243480).

## Credits

Coding was done by me, Rebecca "ToxicFrog" Kelly; no code from other mods is incorporated, but I did learn a great deal about ZScript by studying existing mods, especially LegenDoom, MetaDoom, Universal Pistol Start, Champions, and Corruption Cards.

I also owe a debt of gratitude to everyone on the Secreta Lounge who helped me learn the ins and outs of Doom modding, answered my incessant questions about ZScript, and playtested early versions of these mods.

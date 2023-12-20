# Gun Bonsai

Gun Bonsai is a mod about growing your weapons from delicate pain saplings into beautiful murder trees. It is designed for maximum compatibility; it works in both gzDoom and lzDoom, supports multiplayer, and pairs well with total conversions and monster/weapon replacements, especially ones that increase the overall difficulty.

As you fight the hordes of hell, your weapons will gain XP based on how much damage you do and what you're attacking. Once a weapon levels up, you can open the info screen to browse a list of randomly selected upgrades (four by default), of which you can pick one. Higher levels take more XP to earn, but some upgrades can only be unlocked on high-level weapons.

Every seven weapon levels, you also get to choose a player upgrade: a powerful bonus that is always in effect no matter what weapon you're wielding.

It is also highly configurable, allowing you to tweak the balance to your liking.

It is inspired primarily by [War of Attrition](https://fissile.duke4.net/fissile_attrition.html), heartily seasoned with [LegenDoom](https://forum.zdoom.org/viewtopic.php?t=51035) and a bit of [DoomRL](https://drl.chaosforge.org/).


## Setup

Add `GunBonsai-<version>.pk3` to your load order. It doesn't matter where.

Gun Bonsai adds one new mandatory command, "Show Info", bound to `I` by default; this shows you information on your character and current weapon, and is used to select upgrades on level-up. If you are playing with Legendoom integration (see below), you will also want to make sure "Cycle Legendoom Power" is bound to something convenient.

Gun Bonsai also has its own options page, with many tuning and compatibility options. The defaults should be sensible for vanilla Doom 2 play, but I highly recommend flipping through it and making sure they are to your taste; the settings are self-documenting with in-game tooltips. In particular, if you are using a mod that assigns points (like Reelism, Lazy Points, or MetaDoom) and want to earn XP that way, you will need to adjust some settings.


## Gameplay

As you damage enemies, your current weapon gains XP. Once it gains a level, the Bonsai HUD starts glowing and you can press the Show Gun Bonsai Info binding (by default `I`) to select an upgrade.

Once you've leveled up your weapons enough, you get a player upgrade; the same process applies here, just press `I` to open the menu and choose an upgrade.

You can also open the menu at any time to view your current upgrades, and toggle them on and off; this can be useful if an upgrade your previously selected turns out not to work well with your current loadout.

For a complete list of upgrades, see the [UPGRADES file](./UPGRADES.md).


## Mod Compatibility

This should be compatible with pretty much every IWAD and mod, including weapon/enemy replacements and total conversions. It relies entirely on event handlers and inventory items, and doesn't rely on replacing or modifying existing actors.

It has been tested (although not necessarily extensively) and is known to work with:
- Doom, Doom 2, Heretic, Chex Quest, Hedon Bloodrite, Ashes 2063, and Ashes Afterglow
- Champions and Colourful Hell
- DoomRL Arsenal
- LegenDoom and LegenDoomLite
- MetaDoom
- Reelism 2
- Trailblazer
- Lots of smaller mutators like War Trophies, Slomo Bullet Time, MOShuffle, etc
- and more!

Some mods have special integration features or require specific compatibility settings; these are detailed below. Make sure to also check the [known issues](#known-issues) section for bugs that only manifest with paired with specific mods.

### AutoAutoSave

If you have this installed, turning on `autosave after level-up` will make it request a save from AAS when you close the menu after choosing your upgrades.

### Indestructable

If you have my other mod, [Indestructable](../indestructable), installed, you can turn on `Gun Bonsai integration` in its settings, which will add an `Indestructable` upgrade to the player upgrade pool that lets you earn extra lives by taking damage.

### Score mods (including LazyPoints, MetaDoom, and Reelism)

Gun Bonsai has optional integration with mods that award points for actions such as kills. To enable this, adjust the `XP gain from damage` and `XP gain from score` options. The default is to award 1 XP per point of damage dealt, and ignore score entirely.

If you're using a scoremod, setting `XP gain from score` to a value above 0 will cause you to earn that much XP per point earned. This should work with any mod that uses the `PlayerPawn.score` property or `ScoreItem` class to award the player points, and has been tested to work with Lazy Points, MetaDoom, and Reelism.

Here are the settings I use for those mods; you'll probably want to tweak them based on personal taste, but these may be a useful starting point:

- **LazyPoints**: 0.0 damage, 1.0 score. LP awards bonus points for kills, secrets, items, keys, combos, and having high health, but awards less points for dealing damage (due to not having a scaling score bonus for more dangerous enemies). It works out about the same in the end.
- **MetaDoom**: 0.75 damage, 0.25 score. MD awards bonuses for kills (not damage), plus huge score bonuses for all kills/secrets/items on a level. These settings tend to result in getting more XP than the default overall, but MD also tends to be harder than vanilla, so it works out in the end.
- **Reelism**: I haven't tested this extensively yet, but 1.0 damage/0.5 score seemed to work ok for a first pass; Reelism rounds are pretty short.

### Legendoom

If you have Legendoom installed, legendary weapons can gain new Legendoom effects on level up. Only one effect can be active at a time, but you can change effects at any time. Weapons can hold a limited number of effects; if you gain a new effect and there's no room for it, you'll be prompted to choose an effect to delete. (Make sure you choose the effect you want to **get rid of**, not one of the ones you want to keep!)

When using a Legendoom weapon, you can press the "Cycle Legendoom Weapon Effect" key to cycle through effects, or manually select an effect from the weapon info screen.

There are a lot of settings for this in the mod options, including which weapons can learn effects, how rapidly effects are learned, how many effect slots weapons have, etc. If you want to play with Legendoom installed but turn off integration with Gun Bonsai, set `Gun Levels per Legendoom Effect` to 0/Disabled in the settings.

### Hideous Destructor

Hideous Destructor replaces a lot of default Doom behaviours, in ways that Gun Bonsai has trouble coping with. A non-exhaustive list of issues:
- all `Scavenge` upgrades are disabled
- damage is not always properly converted into XP
- some upgrades are kind of crashy on some weapons
- dead enemies may still register as alive to minions/submunitions/etc

You also need to set the `treat weapons that don't use ammo as wimpy` option to `off` or it will spawn the wrong upgrades on most weapons.

It still works, mostly, but Gun Bonsai is definitely confused by HDest and I can't guarantee that it won't break parts of HDest, too. Caveat lusor.

### Corruption Cards

The combination of Thorns Totem and the Thorns bonsai upgrade can crash the game.

### Pandemonia

Turn "Use Builtin Actors" (`bonsai_use_builtin_actors`) **off**, or armour drops generated by Gun Bonsai will not work properly.

## FAQ

### What do the various upgrades do?

The canonical description of what each upgrade does (including specific numbers) is displayed in-game, via the tooltips that appear when you select an upgrade. (If you can't get tooltips to appear when mousing over an upgrade in the menu, try setting "Enable Mouse in Menus" to "Yes" rather than "Touchscreen-Like".) There is also an [UPGRADES.md](./UPGRADES.md) file, but this does not contain as much detail, and is not always up to date.

### I can't see the HUD! Is it broken?

Go into the settings (Main Menu -> Options -> Full Options Menu -> Gun Bonsai Options). If you're able to view this menu at all, Gun Bonsai is installed and working; adjust the HUD position and size sliders until the HUD is visible.

### Doesn't this make the player a *lot* more powerful?

Yes, especially since I've generally tried to err on the side of upgrades being too powerful rather than too weak. I recommend playing it on a higher difficulty than you're normally comfortable with, and/or pairing it with mods that make things more difficult in general like [Champions](https://forum.zdoom.org/viewtopic.php?t=60456), [Colourful Hell](https://forum.zdoom.org/viewtopic.php?t=47980), [Legendoom Lite](https://forum.zdoom.org/viewtopic.php?t=51035), or [MetaDoom](https://forum.zdoom.org/viewtopic.php?t=53010).

### Can I use parts of this in my mod?

Go nuts! It's released under the MIT license; see COPYING.md for details. See also the "modding notes" section.

### Can I add Gun Bonsai integration to my mod?

Yes! See the `MODDING.md` file for instructions; if you just want to automatically apply a few compatibility tweaks, you probably just need to include a `BONSAIRC` lump in your mod.

### Didn't this used to be called "Laevis"?

Yes -- that was its working title, after *Lepidobatrachus laevis*, aka the Wednesday Frog, which consumes anything smaller than itself and grows more powerful thereby. I eventually settled on "Gun Bonsai" as the release name.

I may someday split the Legendoom integration into its own (somewhat more featureful) mod, in which case it will probably inherit the Laevis name.


## Known Issues

- XP is assigned to the currently wielded weapon at the time the damage is dealt, so it possible for XP to be assigned to the wrong weapon if you switch weapons while projectiles are in flight.
- When using Legendoom, it is possible to permanently downgrade (or, in some cases, upgrade) weapons by changing which effect is active on them before dropping them.
- The distinction between projectile and hitscan weapons is guesswork and may in some cases be incorrect.
- Most effects will trigger only on shots that hit a monster, e.g. HE Rounds will not detonate if you shoot a wall.
- Piercing Shots may interfere with the detonation of exploding shots like rockets.
- Some sound effects (at the moment just the HE and fragmentation sounds) may not play when using iwads other than Doom 1/2.

### Known issues with specific mods

Some of these are minor bugs in the mods themselves that aren't visible in normal play; others are issues with Gun Bonsai that are brought to light by the way these mods work.

- **Ashes series**: all sawn-off shotguns are flagged as melee weapons and thus get melee upgrades
- **Ashes Afterglow**: upgrading a weapon resets it to level 0
- **Angelic Aviary**: some decorations are flagged as monsters and thus grant XP for attacking them
- **DoomRL Arsenal**: building an assembly resets it to level 0
- **Final Doomer +**: HE rounds don't detonate properly
- **Hellrider**: Juggler has no effect
- **Hideous Destructor**: none of the Scavenge upgrades work (in addition to various minor issues)
- **Slomo Bullet Time**: interacts oddly with Swiftness and may cause you to get stuck in place until both effects wear off
- **XRPG**: melee weapons are not flagged correctly and thus get ranged weapon upgrades instead

## Modding Notes

See [MODDING.md](./MODDING.md) for details on:
- building gun bonsai from source
- using parts of it in your on mods
- making mods for it
- adding mod-specific compatibility tweaks


## Credits

Coding was done by me, Rebecca "ToxicFrog" Kelly; no code from other mods is incorporated, but I did learn a great deal about ZScript by studying existing mods, especially LegenDoom, MetaDoom, Universal Pistol Start, Champions, and Corruption Cards.

Most graphics and sounds were taken from FreeDoom and various asset packs on itch.io; see the COPYING file for details. Alternate HUD skins were contributed by Craneo on the ZDoom forums.

I also owe a debt of gratitude to everyone on the Secreta Lounge who helped me learn the ins and outs of Doom modding, answered my incessant questions about ZScript, and playtested this mod.


# Appendix: Upgrade List

This has been moved to [UPGRADES.md](./UPGRADES.md).

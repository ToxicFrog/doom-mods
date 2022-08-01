# Gun Bonsai

Gun Bonsai is a mod about growing your weapons from delicate pain saplings into beautiful murder trees. It is designed for maximum compatibility, and pairs well with total conversions and monster/weapon replacements, especially ones that increase the overall difficulty.

As you fight the hordes of hell, your weapons will gain XP based on how much damage you do and what you're attacking. Once a weapon levels up, you can open the info screen to get a choice of four randomly selected upgrades, of which you can pick one. Higher levels take more XP to earn, but some upgrades can only be unlocked on high-level weapons.

Every seven weapon levels, you also get to choose a player upgrade: a powerful bonus that is always in effect no matter what weapon you're wielding.

It is also highly configurable, allowing you to tweak the balance to your liking.

It is inspired primarily by [War of Attrition](https://fissile.duke4.net/fissile_attrition.html), heartily seasoned with [LegenDoom](https://forum.zdoom.org/viewtopic.php?t=51035) and a bit of [DoomRL](https://drl.chaosforge.org/).


## Setup

Add `libtooltipmenu-<version>.pk3` and `GunBonsai-<version>.pk3` to your load order. It doesn't matter where, as long as `libtooltipmenu` loads first.

Gun Bonsai adds one new mandatory command, "Show Info", bound to `I` by default; this shows you information on your character and current weapon, and is used to select upgrades on level-up. If you are playing with Legendoom integration (see below), you will also want to make sure "Cycle Legendoom Power" is bound to something convenient.

Gun Bonsai also has its own options page, with many tuning and compatibility options. The defaults should be sensible for vanilla Doom 2 play, but I highly recommend flipping through it and making sure they are to your taste; the settings are self-documenting with in-game tooltips. In particular, if you are using a mod that takes away weapons/items (like Universal Pistol Start) or awards points (like Lazy Points, MetaDoom, or Reelism), you will likely need to adjust some settings.


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

It is known be playable with some issues with:
- Final Doomer +
- Hideous Destructor

Some mods have specific integration features or compatibility concerns; these are detailed below.

### Indestructable

If you have my other mod, [Indestructable](../indestructable), installed, Gun Bonsai can add an `Indestructable` upgrade to the player upgrade pool that lets you earn extra lives by taking damage once you select it. To enable this upgrade, adjust the following Indestructable settings:

- `Starting lives`: 0
- `Extra lives at level start`: 0
- `Max lives at level start`: Unlimited

Any other settings will cause it to assume that you want to use Indestructable normally and disable Indestructable/Bonsai integration.

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

### Universal Pistol Start

Gun Bonsai works by storing upgrade information in an item in the player's inventory. If this item gets removed all of your levels and upgrades will disappear. If you want to lose your weapons but keep your upgrades, make sure that `Keep Inventory Items` is enabled in the UPS settings.

### DoomRL Arsenal

This works fine in general, but building an assembly out of a weapon will reset it to level 0 and clear all upgrades on it, even if the upgrade binding mode is to set to `weapon with inheritance` or `weapon class` (because the assembly is not just a different weapon but an entirely different weapon class from the base weapon you used to assemble it).

### Hideous Destructor

Hideous Destructor replaces a lot of default Doom behaviours, in ways that Gun Bonsai has trouble coping with. A non-exhaustive list of issues:
- `Scavenge Lead` doesn't work at all
- `Scavenge Blood` and `Scavenge Steel` produce powerups that may not work properly
- damage is not always properly converted into XP
- some upgrades are kind of crashy on some weapons
- dead enemies may still register as alive to minions/submunitions/etc

It still works, mostly, but Gun Bonsai is definitely confused by HDest and I can't guarantee that it won't break parts of HDest, too. Caveat lusor.

### Ashes 2063/Afterglow

The sawn-off shotgun gets melee upgrades rather than hitscan upgrades. This is a bug in Ashes -- the sawn-off is flagged as a melee weapon.
Installing weapon upgrades in Afterglow will lose all XP and upgrades on the upgraded weapon.

### Final Doomer +

HE rounds don't trigger properly due to an incompatibility with FD+'s custom puff behaviours. This may affect other upgrades as well.

## FAQ

### What do the various upgrades do?

See the "Upgrades" section at the end of this file.

### Doesn't this make the player a *lot* more powerful?

Yes, especially since I've generally tried to err on the side of upgrades being too powerful rather than too weak. I recommend playing it on a higher difficulty than you're normally comfortable with, and/or pairing it with mods that make things more difficult in general like [Champions](https://forum.zdoom.org/viewtopic.php?t=60456), [Colourful Hell](https://forum.zdoom.org/viewtopic.php?t=47980), [Legendoom Lite](https://forum.zdoom.org/viewtopic.php?t=51035), or [MetaDoom](https://forum.zdoom.org/viewtopic.php?t=53010).

### Can I use parts of this in my mod?

Go nuts! It's released under the MIT license; see COPYING.md for details. See also the "modding notes" section.

### Can I add Gun Bonsai integration to my mod?

See "modding notes" below.

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
- The music stops whenever the `Swiftness` upgrade triggers.


## Modding Notes

The ZScript files included in this mod are not loadable as-is; they need to be preprocessed with `zspp`, which is included. The easiest way to do this is simply to run `make` and then retrieve the compiled pk3 from the `release` directory. In addition to `make` itself you will need `find` and `luajit` (for the zscript preprocessor) and the ImageMagick `convert` command (to generate the HUD textures).

You can also simply download a release pk3, unzip it, and edit the preprocessed files.

### Debug commands

You can use netevents to add upgrades and XP using the console:

- `netevent bonsai-debug,w-up,<upgrade name> <levels>`
- `netevent bonsai-debug,p-up,<upgrade name> <levels>`
- `netevent bonsai-debug,w-xp <xp>`
- `netevent bonsai-debug,p-xp <xp>`

`levels` defaults to 1 if unspecified. The `upgrade name` must be the class name, e.g. `TFLV_Upgrade_HomingShots`; as a convenience, it understands `::` as a shorthand for the leading `TFLV_Upgrade_`, e.g. `netevent bonsai-debug,w-up,::HomingShots 5`.

The class names do not always exactly correspond to the human-readable names. Consult `LANGUAGE.en` to find out the class names.

### Reusable Parts

The `GenericMenu`, `StatusDisplay`, and other menu classes are useful examples of how to do dynamic interactive menu creation in ZScript, and how to use a non-interactive OptionsMenu to create a status display.

If you want to use the option menu tooltips, look at [libtooltipmenu](../libtooltipmenu/) instead.

### Adding new Gun Bonsai upgrades

See `BaseUpgrade.zs` for detailed instructions. The short form is: you need to subclass `TFLV_Upgrade_BaseUpgrade`, override some virtual methods, and then register your new upgrade class(es) on mod startup, probably in `StaticEventHandler.OnRegister()`.

### Fiddling with Gun Bonsai's internal state

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


## Credits

Coding was done by me, Rebecca "ToxicFrog" Kelly; no code from other mods is incorporated, but I did learn a great deal about ZScript by studying existing mods, especially LegenDoom, MetaDoom, Universal Pistol Start, Champions, and Corruption Cards.

Graphics and sound were taken from FreeDoom and various asset packs on itch.io; see the COPYING file for details.

I also owe a debt of gratitude to everyone on the Secreta Lounge who helped me learn the ins and outs of Doom modding, answered my incessant questions about ZScript, and playtested this mod.


# Appendix: Upgrade List

This is a list of all the upgrades in the game and their effects and prerequisites. Upgrades have brief in-game descriptions, but this list often has more details.

## Player Upgrades

Upgrades that you gain for your character, and apply no matter what weapon you're wielding.

### Bloodthirsty

Increases all damage you deal by 10% (with a minimum increase of 1) per level. This stacks with per-weapon damage upgrades.

### Indestructable *(max 4 levels)*

**Note:** this requires the mod [Indestructable](../indestructable/) to be installed, or it will not appear in the upgrade pool. See the Mod Compatibility section for required settings.

Gives you extra lives that are automatically expended when you receive lethal damage, restoring some health and temporarily making you invulnerable. Each level reduces the amount of damage you need to take to earn an extra life and increases the maximum number you can carry.

### Juggler *(max 1 level)*

Weapon switching is instantaneous, or nearly so. Note that this does not affect reload speed or rate of fire.

### Scavenge Blood

When killed, enemies drop a health bonus worth 1% of their max health. Level increases the amount of health dropped.

### Scavenge Lead

When killed, enemies drop a random ammo item usable by one of your weapons. If you have multiple weapons that share an ammo type, you're more likely to get ammo of that type. Level increases the number of ammo drops per kill.

### Scavenge Steel

When killed, enemies drop an armour bonus worth 2% of their max health. Level increases the amount of armour dropped.

### Thorns

Enemies attacking you take an equal amount of damage. More levels increases the amount of damage attackers take. Note that you still take full damage from the attack!

### Tough as Nails

Reduces incoming damage by 10% (and by at least 1 point per level). This has diminishing returns as you take more levels of it, and cannot reduce damage taken below 1.


## Generic Weapon Upgrades

Non-elemental upgrades for your weapons.

### Agonizer *(Melee only)*

Hitting an enemy flinches them for 2/5ths of a second. More levels increase the duration.

### Bouncy Shots *(Projectile only)*

Shots bounce off walls. Higher levels increase the number of bounces and decrease the amount of velocity lost on bounce. At level 3, shots bounce off enemies as well.

### Dark Harvest *(Melee only)*

Killing an enemy grants you health and armour equal to 5% of its max health. Unlike the health/armour leech upgrades, this ignores normal health/armour limits and can boost you even beyond Megasphere levels.

### Damage

Increases damage dealt by this weapon by 10%, with a minimum inrease of 1 point, per level.

### Explosive Death *(Ranged only)*

Killing an enemy causes an explosion dealing 20% of (its health + the amount you overkilled it by). Increasing the level increases the damage (with diminishing returns), increases the blast radius (linearly), and reduces the damage you take from the blast.

### Fast Shots *(Projectile only)*

Projectiles move 50% faster per level.

### Fragmentation Shots *(Projectile only)*

On impact, projectiles release a ring of hitscan attacks. Increasing the upgrade level adds more fragments; damage is based on the base damage of the shot. These can't self-damage.

### HE Rounds *(Hitscan only)*

Creates a small explosion on hit doing 40% of the original attack damage. More levels increase the damage and blast radius, and reduce the damage you take from your own explosions.

### Homing Shots *(Projectile only)*

Projectiles home in on enemies. Higher levels will lock on from further away and be more maneuverable when homing.

### Piercing Shots *(Projectile only)*

Shots go through enemies (but not walls). Each level allows shots to go through one additional enemy. Note that most shots will hit enemies multiple times as they pass through, so this also acts as a damage bonus.

### Shield *(Melee only, max two levels)*

Reduces incoming damage by 50% (at level 1) or 75% (at level 2).

### Submunitions *(Weapon only)*

Killing an enemy releases a pile of bouncing explosives. Damage depends on level and how much you overkilled the enemy by; increasing level also increases the number of submunitions.

### Swiftness *(Melee only)*

Killing an enemy gives you a brief moment of time freeze (and some brief slow-mo as it wears off). Killing multiple enemies in rapid succession will extend the duration, as will increasing the level of Swiftness.


## Elemental Upgrades

Elemental upgrades add powerful debuffs and damage-over-time effects to your attacks. They work a bit differently from other upgrades. Each element has four associated upgrades:

- a basic upgrade that activates that elemental status effect on the weapon
- an intermediate upgrade that improves the status effect in a different way than just leveling up the base upgrade
- two *mastery upgrades* that add a powerful new effect, only one of which can be chosen on each weapon; one is designed for AoE combat, the other for tackling individual hard targets.

Higher-rank skills cannot exceed the level of lower-rank ones, and lower-rank skills need to be at least level 2 to unlock higher-rank ones, so the earliest you can get a mastery on a weapon is level 5.

Each weapon can only have two different elements on it. When you choose your first elemental upgrade, that element is "locked in" until you choose a mastery upgrade for it. At that point you can (if you wish) choose a second element on future level-ups. Mastering two elements on a weapon unlocks a special *elemental sythesis upgrade* for it.

Note that unlike the non-elemental upgrades, elemental AoE effects like `Acid Spray` and `Putrefaction` will never harm the player.

## Fire

Fire does more damage the more health the target has, and "burns out" once they're below 50% health. If an enemy that has "burned out" heals, it will start taking fire damage again, making this particularly effective against modded enemies with regeneration or self-healing. More stacks increase both the rate at which damage is dealt and the total amount of damage possible, although it's never enough to actually kill the target. Once an enemy has fire stacks it never loses them; they just become dormant once it drops below the health threshold.

More powerful attacks apply more fire stacks, so it should be good on all weapons.

### Searing Inscription *(Fire basic upgrade)*

Shots cause enemies to ignite. Higher levels apply fire stacks faster and increase the softcap, thus increasing both the DPS and the total damage of the effect.

### Burning Terror *(Fire intermediate upgrade)*

Enemies with fire stacks on them will flee once they drop below a certain level of health. More stacks and higher terror level both contribute to them fleeing earlier. Also provides a bonus to the amount of damage the target takes from fire.

In addition, enemies that are still *taking damage* from fire have a chance to flinch; increased fire damage and terror level both contribute to that chance.

### Conflagration *(Fire mastery)*

Burning enemies with enough stacks on them will pass a proportion of their stacks on to nearby enemies. Higher levels of Conflagration will transfer more stacks and do so in a wider range, as will adding more stacks to the victim.

### Infernal Kiln *(Fire mastery)*

Attacking a burning enemy gives you a stacking bonus to attack and defence that gradually wears off once you stop.

## Poison

Poison is a weak and short-lived damage-over-time effect, but adding more stacks increases both the duration and the damage per second. Both have diminishing returns, but with no upper bound.

The amount of stacks applied is independent of weapon damage, so it's best used with rapid-fire weapons like the chaingun and plasma rifle.

### Venomous Inscription *(Poison basic upgrade)*

Shots poison enemies. Leveling up the upgrade increases how many stacks are applied per attack.

### Weakness *(Poison intermediate upgrade)*

Poisoned enemies do diminished damage. Each stack reduces damage by 1%, with diminishing returns. Leveling this up increases the amount damage is reduced by per stack, although it can never be reduced below 1.

### Putrefaction *(Poison mastery)*

Killing a poisoned enemy causes it to explode in a cloud of poison gas, poisoning everything nearby. Enemies with more poison stacks on them when they die will spread more poison. Leveling this up increases the proportion of poison that gets spread.

### Hallucinogens *(Poison mastery)*

Once an enemy has enough poison stacks on it to eventually kill it, it fights on your side until it dies. Enemies affected by hallucinogens get a damage bonus from Weakness rather than a damage penalty.

## Acid

Acid stacks are slowly converted into damage on a 1:1 basis, but the less health the target has and the more acid stacks they have, the faster this happens.

Acid stacks have a soft cap based on the damage dealt by the attack that inflicted them, so they're best used with weapons that have high per-shot damage like the rocket launcher and SSG. (For shotguns, the total damage of all the pellets that hit is used, not the per-pellet damage.)

### Corrosive Inscription *(Acid basic upgrade)*

Shots poison enemies. The amount of acid applied, and the cap, is 50% of the damage dealt, increased by another 50% per level.

### Concentrated Acid *(Acid intermediate upgrade)*

Each level increases the threshold at which acid damage starts accelerating by 10%, and the ratio at which acid stacks are converted into damage by 10%. Both have diminishing returns.

### Acid Spray *(Acid mastery)*

Attacks that exceed the acid softcap for the target will splash acid onto nearby enemies instead. Spray range and the level of the applied acid depends on your level of Acid Spray. The amount of acid applied depends on how much you've exceeded the softcap by and how much acid you applied in that attack; both doing more damage and exceeding the softcap by more will increase the splash amount.

### Embrittlement *(Acid mastery)*

Enemies with acid stacks on them take 1% more damage from all sources per stack. Enemies with low enough HP die instantly; the threshold is based on the number of acid stacks and your Concentrated Acid and Embrittlement levels.

## Lightning

Lightning does no additional damage on its own, but paralyzes targets. Stacks are applied based on weapon damage and capped based on skill level, so it should be effective with both rapid-fire and single-shot guns.

### Shocking Inscription *(Lightning basic upgrade)*

Shots paralyze enemies (in addition to doing their normal amount of damage). Paralysis is softcapped at 1 second per upgrade level.

### Revivification *(Lightning intermediate upgrade)*

Slain enemies have a chance of coming back as ghostly minions. The chance of coming back increases with both the number of lightning stacks and the level of Revivification; the latter also gives revived minions a bonus to damage and armour. You can freely walk through your minions (so they can't block important doorways), and while they are capable of friendly fire they will never do more than 1 damage to you. (They take full damage from your attacks, however.)

### Chain Lightning *(Lightning mastery)*

Slain enemies release a burst of chain lightning that arcs between targets. Chain length is based on upgrade level; chain damage is based on how much health the dead enemy had, how many lightning stacks it had on it, and how many enemies are caught in the chain in total. It cannot arc to you.

### Thunderbolt *(Lightning mastery)*

Once you sufficiently exceed the lightning softcap on a target, it is struck by lightning, taking damage based on its max health and your level of Thunderbolt, with a bonus based on how many lightning stacks it has. This clears all lightning stacks on the target.

## Elemental Sythesis Powers

Once you have two elemental masteries on a weapon, you have a chance for one of these upgrades -- **Elemental Beam**, **Elemental Blast**, or **Elemental Wave** -- to show up. Each of these copies the elemental effects on whatever enemy you're attacking to other nearby enemies. Only the basic version of the element is copied -- for example, copied lightning won't proc **Thunderbolt** -- but this can still be quite powerful.

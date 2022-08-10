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
- and more!

Some mods have special integration features or require specific compatibility settings; these are detailed below. Make sure to also check the [known issues](#known-issues) section for bugs that only manifest with paired with specific mods.

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

Gun Bonsai works by storing upgrade information in an item in the player's inventory. If this item gets removed all of your levels and upgrades will disappear. If you want to lose your weapons but keep your upgrades, make sure that `Keep Inventory Items` is enabled in the UPS settings, and that your upgrade binding setting is set to `weapon class` or `individual with inheritance`.

### Hideous Destructor

Hideous Destructor replaces a lot of default Doom behaviours, in ways that Gun Bonsai has trouble coping with. A non-exhaustive list of issues:
- `Scavenge Lead` doesn't work at all
- `Scavenge Blood` and `Scavenge Steel` produce powerups that may not work properly
- damage is not always properly converted into XP
- some upgrades are kind of crashy on some weapons
- dead enemies may still register as alive to minions/submunitions/etc

It still works, mostly, but Gun Bonsai is definitely confused by HDest and I can't guarantee that it won't break parts of HDest, too. Caveat lusor.

## FAQ

### What do the various upgrades do?

See the "Upgrades" section at the end of this file.

### I can't see the HUD! Is it broken?

Go into the settings (Main Menu -> Options -> Full Options Menu -> Gun Bonsai Options). If you're able to view this menu at all, Gun Bonsai is installed and working; adjust the HUD position and size sliders until the HUD is visible.

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

Killing an enemy drops a health bonus worth 1 point per level (×10 for boss kills). This is capped at 100% of your normal max health, raised to 200% at level 2.

### Scavenge Lead

When killed, enemies drop a random ammo item usable by one of your weapons. If you have multiple weapons that share an ammo type, you're more likely to get ammo of that type. Level increases the number of ammo drops per kill.

### Scavenge Steel

Killing an enemy drops an armour bonus worth 2 points per level (×10 for boss kills). This is capped at 100% of your normal max health, raised to 200% at level 2.

### Thorns

Enemies attacking you take damage in proportion to the amount of damage they dealt, increasing as they get closer to you. Enemies that are close enough will also suffer the elemental effects of your weapon as if you had shot them. Increasing the level increases both the amount of damage returned and the effective radius.

Note that you still take full damage from the attack!

### Tough as Nails

Reduces incoming damage by 10% (and by at least 1 point per level). This has diminishing returns as you take more levels of it, and cannot reduce damage taken below 1.


## Generic Weapon Upgrades

Non-elemental upgrades for your weapons.

### Bouncy Shots *(Projectile only, incompatible with Piercing Shots)*

Shots bounce off walls. Higher levels increase the number of bounces and decrease the amount of velocity lost on bounce. At level 3, shots bounce off enemies as well.

### Dark Harvest *(Melee only)*

Killing an enemy grants you 1 point of health and armour per level (×10 for boss kills). This is capped at 100% of your max health, +20% for each level (so 120% at level 1 and 200% at level 5). If you boost it above level 5 you can exceed the normal 200 health/armour limit.

### Damage

Increases damage dealt by this weapon by 10%, with a minimum inrease of 1 point, per level.

### Explosive Death *(Ranged only)*

Killing an enemy causes an explosion dealing 20% of (its health + the amount you overkilled it by). Increasing the level increases the damage (with diminishing returns), increases the blast radius (linearly), and reduces the damage you take from the blast.

### Fast Shots *(Projectile only)*

Projectiles move 50% faster per level.

### Fragmentation Shots *(Projectile only, incompatible with Piercing Shots)*

On impact, projectiles release a ring of hitscan attacks. Increasing the upgrade level adds more fragments; damage is based on the base damage of the shot. These can't self-damage.

### HE Rounds *(Hitscan only)*

Creates a small explosion on hit doing 40% of the original attack damage. More levels increase the damage and blast radius, and reduce the damage you take from your own explosions.

### Homing Shots *(Projectile only)*

Projectiles home in on enemies. Higher levels will lock on from further away and be more maneuverable when homing.

### Piercing Shots *(Projectile only, requires two levels of Fast Shots)*

Shots go through enemies (but not walls). Note that most shots will hit enemies multiple times as they pass through, so this also acts as a damage bonus which hits harder against larger enemies.

### Shield *(Melee only, max two levels)*

Reduces incoming damage by 50% (at level 1) or 75% (at level 2).

### Submunitions *(Ranged only)*

Killing an enemy releases a pile of bouncing explosives. Damage depends on level and how much you overkilled the enemy by; increasing level also increases the number of submunitions.

### Swiftness *(Melee only)*

Killing an enemy gives you a 1 second of time freeze (+200ms per additional level). You can extend this by killing more enemies before it wears off.


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

Once you have two elemental masteries on a weapon, you have a chance for one of these upgrades to show up. Each one of them copies all the elemental effects on whatever you're attacking to other enemies. Only the basic version of the element is copied -- for example, copied lightning won't proc **Thunderbolt** -- but this can still be quite powerful.

There are three of these, for three different kinds of weapons:
- **Elemental Beam** appears on hitscan weapons and copies elements to all enemies in a line
- **Elemental Blast** appears on projectile weapons and copies elements to all enemies near your target
- **Elemental Wave** appears on melee weapons and copies elements to all enemies near you.

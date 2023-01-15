# Upgrade List

This is a list of all the upgrades in Gun Bonsai and their effects and prerequisites. Upgrades have brief in-game descriptions, but this list often has more details.

## Player Upgrades

Upgrades that you gain for your character, and apply no matter what weapon you're wielding.

### Bloodthirsty

Increases all damage you deal by 10% (with a minimum increase of 1) per level. This stacks with per-weapon damage upgrades.

### Indestructable *(max 4 levels)*

**Note:** this requires the mod [Indestructable](../indestructable/) to be installed, or it will not appear in the upgrade pool. See the Mod Compatibility section for required settings.

Gives you extra lives that are automatically expended when you receive lethal damage, restoring some health and temporarily making you invulnerable. Each level reduces the amount of damage you need to take to earn an extra life and increases the maximum number you can carry.

### Intuition *(max 2 levels)*

At level 1, you start every level with the map revealed. At level 2, the locations of most actors are revealed on the map as well.

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

### Cleave *(Melee only)*

Killing an enemy in melee automatically gets you a free attack against another nearby enemy. Damage scales with how much you overkilled the original target by *and* how much health it spawned with.

### Dark Harvest *(Melee or Wimpy only)*

Killing an enemy grants you 1 point of health and armour per level (×10 for boss kills). This is capped at 100% of your max health, +20% for each level (so 120% at level 1 and 200% at level 5). If you boost it above level 5 you can exceed the normal 200 health/armour limit.

### Damage

Increases damage dealt by this weapon by 20%, with a minimum increase of 1 point, per level.

### Explosive Death *(Ranged only)*

Killing an enemy causes an explosion dealing 20% of (its health + the amount you overkilled it by). Increasing the level increases the damage (with diminishing returns), increases the blast radius (linearly), and reduces the damage you take from the blast.

### High Velocity *(Projectile only)*

Projectiles move 50% faster per level.

### Fragmentation Shots *(Projectile only, incompatible with Piercing Shots)*

On impact, projectiles release a ring of hitscan attacks. Increasing the upgrade level adds more fragments; damage is based on the base damage of the shot. These can't self-damage.

### HE Rounds *(Hitscan only)*

Creates a small explosion on hit doing 40% of the original attack damage. More levels increase the damage and blast radius, and reduce the damage you take from your own explosions.

### Homing Shots *(Projectile only)*

Projectiles home in on enemies. Higher levels will lock on from further away and be more maneuverable when homing.

### Piercing Shots *(Projectile only, requires two levels of Fast Shots, max 1 level)*

Shots go through enemies (but not walls). Note that most shots will hit enemies multiple times as they pass through, so this also acts as a damage bonus which hits harder against larger enemies.

### Rapid Fire *(Max 10 levels; weapons with ammo only)*

Increases attack speed by 50% (additive). Maxes out at +500% (6x normal attack speed). High levels may have graphical glitches. This is a great way to get more DPS, but it comes at the cost of increased ammo consumption.

### Shield *(Melee or Wimpy only)*

Reduces incoming damage by ~20%. Can be stacked, with diminishing returns maxing out at 60% damage reduction. Cannot reduce incoming damage below 1 point.

### Submunitions *(Ranged only)*

Killing an enemy releases a pile of bouncing explosives. Damage depends on level and how much you overkilled the enemy by; increasing level also increases the number of submunitions.

### Sweep *(Melee only)*

Attacking an enemy in melee does a portion of the damage to other enemies that are in melee range of both you and your target.

### Swiftness *(Melee or Wimpy only)*

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

Lightning does no additional damage on its own, but slows targets. Stacks are applied based on weapon damage and capped based on skill level, so it should be effective with both rapid-fire and single-shot guns. More stacks extend the duration but do not intensify the effect.

### Shocking Inscription *(Lightning basic upgrade)*

Shots reduce targest to half speed (in addition to doing their normal amount of damage). Paralysis is softcapped at 1 second per upgrade level.

### Thunderbolt *(Lightning intermediate upgrade)*

Once you sufficiently exceed the lightning softcap on a target, it is struck by lightning, taking damage based on its max health and your level of Thunderbolt, with a bonus based on how many lightning stacks it has. This clears all lightning stacks on the target. Increasing the level increases both the damage and how frequently it triggers.

### Revivification *(Lightning mastery)*

Slain enemies have a chance of coming back as ghostly minions. The chance of coming back increases with both the number of lightning stacks and the level of Revivification; the latter also gives revived minions a bonus to damage and armour. You can freely walk through your minions (so they can't block important doorways), and while they are capable of friendly fire they will never do more than 1 damage to you (and take only 1 damage from your attacks).

### Chain Lightning *(Lightning mastery)*

Slain enemies release a burst of chain lightning that arcs between targets. Chain length is based on upgrade level; chain damage is based on how much health the dead enemy had, how many lightning stacks it had on it, and how many enemies are caught in the chain in total. It cannot arc to you.

## Elemental Sythesis Powers

Once you have two elemental masteries on a weapon, you have a chance for one of these upgrades to show up. Each one of them copies all the elemental effects on whatever you're attacking to other enemies. Only the basic version of the element is copied -- for example, copied lightning won't proc **Thunderbolt** -- but this can still be quite powerful.

There are three of these, for three different kinds of weapons:
- **Elemental Beam** appears on hitscan weapons and copies elements to all enemies in a line
- **Elemental Blast** appears on projectile weapons and copies elements to all enemies near your target
- **Elemental Wave** appears on melee weapons and copies elements to all enemies near you.

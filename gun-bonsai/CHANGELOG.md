# 0.10.0

- New:
  - Cool fizzy effect when a Revivification minion dies.
- Balance:
  - Thunderbolt is now the intermediate lightning upgrade.
  - Revivification is now one of the two lightning masteries, opposite Chain Lightning.
  - Revivification always succeeds (if the target can be revived at all), but is limited to a single minion.
  - Killing a more powerful enemy has a chance to replace your current minion with the enemy you just killed.
  - Minions are now erased on death to prevent them from being re-raised by viles and the like.
  - Your minion does not die after a period of time out of combat.
  - Minion damage reduction applies to all players, not just the player who raised them.
  - Revivification can't raise bosses. No pet Cyberdemon, sorry.
- Fix:
  - Friendly monsters, if they have a controlling player (via the `FriendlyPlayer` field), will inherit that player's attack upgrades, and that player will get XP for the monster's attacks.
  - Revivified monsters properly set the `FriendlyPlayer` field to the player that raised them.
  - Revivified monsters properly take and receive 1 damage from the player again.
  - Killing an unraisable monster no longer creates a Revivification helper actor that sticks around forever.

# 0.9.8

- New:
  - `bonsai_vfx_mode` setting can be used to turn off particle effects, optionally replacing them with sprite-flash effects.
  - Armour cap for upgrades that produce armour (Dark Harvest and Scavenge Steel) is now based on the armour rating of the best armour you have found thus far, or your health if you haven't found any armour yet. In vanilla Doom this means it starts at 100 and increases to 200 the first time you grab a blue armour or a Megasphere. This is still fairly experimental but should hopefully improve compatibility with mods that have unusually high/low armour caps.
  - `netevent bonsai-debug,allupgrades` command to add all the upgrades to you at once. For save-testing purposes only -- may cause serious gameplay issues.
- Balance:
  - Shocking Inscription now reduces enemies to 50% speed rather than paralyzing them completely.
  - Submunitions now gains 1 bomblet per level rather than 4.
  - Fragmentation Shots now start at 8 fragments rather than 16, and gain 2 per level rather than 8.
  - Dark Harvest starts at 100% rather than 120%.
- Fix:
  - Burning Terror now respects the `+NOFEAR` flag.
  - Thunderbolt now procs on DoT tick, which may fix crashes attacking certain enemies with Thunderbolt-enabled weapons.
  - Swiftness description now properly notes that it triggers on all kills, not just melee ones (although it will still prefer to spawn on melee weapons).

# 0.9.7

- New:
  - Gun Bonsai logs its release version and git commit ID to the console on startup.
- Fix:
  - Rapid Fire now works properly with Doom Nukem, and probably a lot of other mods where it didn't work right before.
  - libtooltipmenu is now integrated. This fixes compatibility with other mods that have improperly copied libttm into their pk3.
  - Upgrade tooltips no longer show a diff against a theoretical level 0 upgrade when choosing them for the first time.
  - The Thorns tooltip no longer causes a division by 0 crash on some builds of gzDoom.
- Change:
  - Thunderbolt now uses a sprite effect rather than a huge number of particle effects when it triggers.

# 0.9.6

- New:
  - Upgrades can now declare tooltips that will display in the status and level-up menus for additional detail.
  - Tooltips added for most upgrades, showing specific numbers for their effects and previewing the effects of level-ups.
  - As a debugging tool, you can set `bonsai_upgrade_choices_per_player_level` and `bonsai_gun_choices_per_player_level` to -1 to list all upgrades. This will produce upgrade choices that do not work, so it is mostly useful for testing menu display code.
- Balance:
  - Swiftness now goes into slow-mo for the last 0.5s of its duration rather than the last 3.5s, meaning it does actually stop time even at low levels.
  - Piercing Shots now applies a damage penalty. Taking more levels mitigates the penalty
- Fix:
  - Heretic's wand and staff are now considered "wimpy" weapons.
  - Some errors in `UPGRADES.md` about what upgrades were available on what weapons corrected.
  - Shield now properly stacks infinitely, albeit with diminishing returns.
  - Scavenge Lead spawns now respect actor replacement rules.
  - Dark Harvest now respects permanent health upgrades when calculating the cap.
  - Burning Terror now gives +1 dps per level, rather than +5 dps every five levels.

# 0.9.5

- New:
  - Multiplayer support! There may still be some issues but hopefully they should be more on the "weird glitch" side than the "desyncs/breaks" side.
  - Thank you Dan_The_Noob in particular for testing MP!
- Fix:
  - Crash when Thunderbolt triggers on an enemy as it's killed when certain mods are installed.

# 0.9.4

- New:
  - "Ammoless weapons are wimpy" setting; turn this off for Hideous Destructor
  - HUD opacity setting
  - Complete Brazilian Portugese translation for options screen
- Balance:
  - Thunderbolt is now a bit easier to trigger, and gets easier as you add more levels
  - Rapid Fire now increases attack speed by 50%
  - Rapid Fire now caps at 10 (6x IAS) rather than 1 (2x)
  - Rapid Fire is available only on weapons that use ammo, to prevent it from being strictly better than Damage+ on weapons without
- Fix:
  - Improved Hideous Destructor compatibility (thanks to Ted the Dragon)
  - Internal cleanup of how cvars are accessed
  - Revivified enemies no longer have their `master` set to the player, so enemies with (e.g.) `KillMaster` scripts won't vaporize the player when revived
  - Elemental Synthesis upgrades copy all properties, not just the base level, of elemental effects
  - OnActivate effects like rapid fire now persist properly across level transitions

# 0.9.3

- New:
  - `WIMPY` weapon type support in BONSAIRC
  - full `LANGUAGE` support for the options menu, all of Gun Bonsai can now be translated!
- Balance:
  - XP cost reductions for Wimpy and Melee weapons no longer stack; weapons that are both will have whichever is lower of the two costs
  - (experimental) Weapons that do not use ammo are considered Wimpy
  - (experimental) Some previously melee-only upgrades -- Shield, Dark Harvest, and Swiftness -- are now also available on wimpy weapons
- Fix:
  - Melee weapon detection reverted to its pre-0.9 behaviour of trusting the +MELEEWEAPON flag, since the more complicated approaches caused more problems than they solved
  - LegenDoom bonus effects are now earned at the correct levels
  - LZDoom compatibility restored
  - Tentative fix for XP overflow issues some users have reported
  - Crash in WorldThingSpawned if the thing spawned stops existing before the event handler is called; this doesn't happen in normal play but some mods can cause it

# 0.9.2 hotfix

- Change:
  - Updates to Brazilian Portugese translation
- Fix:
  - Crash on TITLEMAP and some other situations where the PlayerPawn exists but has no weapon equipped
  - Debug messages were left enabled in the release build
  - Missing description and name for Intuition upgrade

# 0.9.2

- New:
  - Intuition player upgrade reveals map geometry and actor locations
  - Rapid Fire weapon upgrade doubles firing speed
  - LANGUAGE lump support:
    - gameplay log/printf messages (except for debug messages)
    - level-up and status displays
    - menu titles and enum names (full support for options menu coming next version)
  - partial Brazilian Portugese translation by Generic Name Guy
- Balance:
  - Revivified enemies will now die after a few seconds out of combat, hopefully fixing "I revived something and now it won't die and the level scripting is broken" issues
  - Revivification triggers more often to make up for the fact that enemies can no longer be kept as pets for the entire level
- Change:
  - Fast Shots renamed High Velocity to address confusion about whether it affects shot travel speed or rate of fire
  - upgrade appendix moved into [its own file](./UPGRADES.md)
  - OnActivate/OnDeactivate API enabling new kinds of upgrades to be written
  - melee weapon detection should be more permissive now
  - builtin upgrades are now registered via BONSAIRC lump
- Fix:
  - crash when opening the menu while no weapon is equipped

# 0.9.1

- New: number of upgrades you can choose from on level up is configurable
  - Player and weapon counts can be configured separately
  - A setting of 1 will randomly choose an upgrade for you as soon as you gain a level
  - A setting of 0 will let you choose from the complete list of available upgrades
- New: improved weapon type inference code
  - detects melee weapons based on average engagement range rather than trusting the (often missing or misused) `+MELEEWEAPON` flag
  - detects FastProjectile weapons and weapons firing seeking, bouncing, and ripping projectiles
  - these types can also be set manually in the BONSAIRC lump
  - upgrade selection will avoid spawning upgrades that don't work (e.g. Homing on a FastProjectile weapon) or are redundant (e.g. Piercing on a weapon that fires ripper shots)
- New: `bonsai-level-up` netevent is emitted when you gain enough XP to level up (before you open the menu and choose an upgrade)
- New: emitted netevents are now documented in [MODDING.md](./MODDING.md)
- Change: "base level cost" menu item is now a textfield
- Change: the player levelup menu will no longer open automatically on levelup
- Change: `bonsai_show_info_console` replaced with `bonsai-dump`, which is an alias for `netevent bonsai-debug,info`.
- Change: `bonsai_choose_level_up_option` netevent renamed `bonsai-choose-level-up-option`. The old netevent is still emitted for backwards compatibility with AutoAutoSave but will be removed in 0.10.x.
- Change: a number of other netevents were renamed but as far as I know no-one else was using them for anything, so they don't get compatibility shims
- Balance: Damage (weapon) is now +20%/+1 rather than +25%/+2
- Balance: Shield is now 20% and stacks up to a max of 60%, rather than 50% -> 75%
- Balance: Shield cannot reduce incoming damage below 1
- Fix: HUD should now render overtop of other HUD elements
- Fix: Hexen cleric mace & Strife punch dagger are now considered melee weapons
- Fix: BONSAIRC now reports when it's enabling conditional configurations, and which ones
- Fix: BONSAIRC now produces a single error and stops parsing when encountering a malformed type, enable, or disable command
- Fix: Lightning will *probably* no longer permanently paralyze enemies, or (in some mods) make them immortal
- Fix: Homing Shots now properly sets the `+SEEKERMISSILE` flag on projectiles
- Fix: the levelup flash/sound settings are now respected for player levelups
- Fix: crash when subjected to an instadeath (e.g. bottomless pit) that kills `PlayerInfo` but leaves `PlayerPawn` intact
- Fix: crash when the player's inventory is taken away (fixes Blade of Agony)

# 0.9.0

**This release breaks save compatibility.**

- New: BONSAIRC chunk support (see `MODDING.md` for details)
  - Text chunk that contains rules for configuring Gun Bonsai based on what mods are loaded
  - Selectively enable or disable upgrades globally
  - Override Bonsai's weapon type detection for individual weapons
  - Disable individual upgrades on a per-weapon basis, or disable all upgrades for a weapon
  - Mark certain weapons as equivalent to each other and thus capable of sharing upgrades (e.g. a base weapon and its upgraded form)
- New: upgrades can be carried from weapons to their upgraded forms
  - The weapon and its upgrade(s) must be marked as merged in a BONSAIRC lump
  - The old weapon must be removed and the new weapon added in the same game tic if using "upgrades bind to individual weapons"
- New: `bonsai-debug,reset` debug command
- New: upgrades are now kept across death-exits and pistol starts
  - "keep upgrades on death exit" option controls this behaviour
- New: upgrades can be selectively toggled on and off from the info menu
- Fix: Weapons retain their upgrades when empowered by the Tome of Power
- Fix: rejecting a player level-up now refunds half the cost of that level, rounded up
- Fix: A number of general compatibility fixes that especially benefit Hexen; many projectile weapon upgrades now function that didn't before
- Game-specific fixes:
  - Hexen: several weapons had upgrades that do not work on them, or which duplicate effects already built into the weapon, disabled
    - some of these will eventually turn into general fixes but for now they are a Hexen-specific tweak
  - Hellrider: Juggler will no longer be offered as an upgrade
  - Hideous Destructor: non-weapons like the clip manager no longer earn XP and level up
  - Ashes Afterglow: sawn-off now gets hitscan upgrades instead of melee
  - Ashes Afterglow: upgrading a weapon keeps the upgrades on it

# 0.8.6 hotfix

- Fix: crash on startup when using -warp, +load, or other commands that bypass the main menu

# 0.8.6

- Change: HUD scale is now always set as a fraction of screen size rather than a size in pixels
- Change: HUD text layout adjusted, now shows level and XP for both player and weapon
- Change: lightning now freezes enemies into their current state rather than their pain state
- Balance: Burning Terror no longer triggers pain, but recovery from fear takes longer.
- Balance: Piercing Shots now requires two levels of Fast Shots
- Balance: Piercing Shots is now mutually exclusive with Bouncy Shots and Fragmentation Shots
- Fix: HUD text now scales properly with screen size and HUD size
- Fix: Fire and Lightning effects no longer make Hexen Centaurs immortal
- Fix: Bouncy Shots no longer makes things worse when taken on an already-bouncy weapon (making it not appear on those weapons at all will be fixed in a future version)
- Fix: Bouncy Shots no longer slow down when hitting a wall

# 0.8.5

- Balance: Fire now burns slightly less aggressively
- Balance: Burning Terror triggers more easily but enemies will eventually recover from it
- Fix: remove stray VFX from Swiftness that were left in there from debugging
- Fix: Infernal Kiln and Conflagration should now actually be available in the upgrade pool

# 0.8.4

- Balance: Swiftness now grants 35 tics (+7 per additional level) per kill
- Balance: Swiftness cap is now the same as the initial grant, and increases by 5 tics per kill during a swiftness combo
- Balance: Submunitions no longer trigger more Submunitions on kill
- Fix: music and sound effects no longer stop when Swiftness triggers
- Fix: crash when using `bonsai-debug,w-up` incorrectly
- Fix: crash when using Elemental Blast or Elemental Wave and the target vanishes unexpectedly
- Fix: HP/AC caps for Scavenge and Dark Harvest are now based on the player's max health FOR REAL THIS TIME

# 0.8.3

- Balance: Thorns reflects more damage the closer enemies get, but no damage at all to distant enemies.
- Balance: Thorns only procs elemental effects on nearby enemies.
- Change: README compatibility/known issues sections reworked some; compat note for Hellrider
- Fix: crash when dying with the Juggler upgrade
- Fix: attacking friendlies no longer awards XP or procs upgrade effects
- Fix: HP/AC caps for Scavenge and Dark Harvest are now based on the player's max health rather than on a hardcoded value of 100.
- Fix: crash when using debug commands to add an upgrade that doesn't exist

# 0.8.2

- New: health/armour drops cast light.
- New: WIP LZDoom compatibility. Some menus have rendering problems but it is playable.
- New: compatibility note about Final Doomer.
- New: FAQ entry about the HUD being covered up by other UI elements.
- New: options to disable the level-up flash and sound effect
- New: alternate HUD skins selectable from the options, thanks to Craneo
- Change: default HUD position changed to top right to make it less likely to be covered by other HUDs by default.
- Balance: Poison Shots no longer depends on a puff. This makes it consistent with the other elemental upgrades. This means that (like the other such upgrades) it can trigger in a variety of situations that might not make sense, so this behaviour might be revised in a future version.
- Balance: HE Rounds damage bonus reduced from 40%/0 (what was I thinking?) to 10%/1. It's now an actual choice between the Damage upgrade for pure damage output or HE Rounds for area of effect.
- Balance: HE Rounds damage falls off more gradually.
- Balance: Dark Harvest now restores a flat 1/1 hp/ac per level, x10 for bosses, capped at 100 + 20/level.
- Balance: Scavenge Blood restores a flat 1 hp, with a cap of 100 at level 1 and 200 at level 2+
- Balance: Scavenge Steel restores a flat 2 ac, with a cap of 100 at level 1 and 200 at level 2+
- Fix: some errors in README corrected; layout improved.
- Fix: Juggler caused rendering errors when paired with weapon states that manually adjusted the weapon y-offset.
- Fix: crash when Chain Lightning can't find anything to arc to or from at all
- Fix: Submunitions are meant to be ranged-only

# 0.8.1

- New: Chain Lightning has a pretty on-hit graphic.
- New: Console debug interface using `netevent bonsai-debug`. See the README for details.
- Balance: Chain Lightning minimum arc distance increased to make it more viable against small enemies
- Fix: intermitten crash when Homing Projectiles impact something.
- Fix: crash when enemies are erased after Chain Lightning starts arcing to them but before it finishes.

# 0.8.0

**Note:** Renamed to Gun Bonsai (from Laevis) for general release.
**Note:** If upgrading from any earlier version, *all of your configuration will be reset to defaults*.

- New: Blast Shaping upgrade significantly reduces self-damage
- New: Thorns upgrade copies damage you take onto your enemies
- New: Juggler upgrade gives you instant weapon switching
- New: fancier tooltips via libtooltip-0.1.1
- New: fancy graphics for HP/AP bonuses from <willibab.itch.io>
- New: the level-up menu opens next time you open the weapon info screen, rather than immediately
- New: rejecting a level-up with ESC still costs XP but does not level-up the weapon (and thus increase the XP cost for the next level)
- New: rejecting a player level-up now refunds half the cost of the level
- New: HUD gets all fancy when it's level-up time
- New: Indestructable upgrade integrates with the mod of the same name
- New: a sound plays on level-up to make it harder to miss
- Change: README cleaned up and improved somewhat
- Balance: Armour and Resistance merged into a single upgrade, Tough as Nails, and buffed
- Balance: player damage upgrade renamed Bloodthirsty, now grants +10%/1 damage instead of +5%/1
- Balance: weapon damage upgrade now grants +25%/2 damage instead of +10%/1 to make it more competitive with other upgrades
- Balance: player upgrades default to every 7 levels instead of every 10
- Fix: Scavenge Lead no longer spawns ammo types that don't have a valid sprite defined. In particular, this fixes an issue with Ashes 2063.
- Fix: OnDamageReceived handlers believed all damage was self-inflicted
- Fix: trying to cycle Legendoom weapon effects when wielding a weapon with no effects crashed the game
- Fix: setting "gun levels per LD effect" to 0 would crash the game next time you leveled up
- Fix: earning large amounts of XP at once made it possible to take otherwise impossible combinations of upgrades

# 0.7.4

- New: README contains information about discovered incompatibilities with Hideous Destructor
- Balance: Fire tree rework
  - Fire damage rate increased
  - Searing Heat removed; you now get the same effect by applying more fire stacks
  - Infernal Kiln stacks still decay with time but no longer decay faster when you attack
  - Conflagration ignition radius significantly increased, and scales with actor size
  - Conflagration still procs even once the enemy is no longer burning
  - new intermediate upgrade: Burning Terror causes enemies to flee and flinch while burning
- Fix: XP wasn't gained for damage-over-time effects
- Fix: XP gained didn't properly correspond to damage in some circumstances
- Fix: Explosive Shots could crash in some circumstances
- Fix: overkilling an enemy could result in negative XP

# 0.7.3

- New: support for DamNums; Laevis damage types will be coloured to match their upgrade names
- New: XP-from-damage and XP-from-score can both be turned on the same time, with independent multipliers
- New: Fragmentation Shots are now fast-moving projectiles rather than hitscans
- Balance: remove Agonizer from the melee upgrade pool, as it's redundant with Shock
- Balance: Revivified enemies only take 1 damage from the player
- Balance: Fragmentation Shots now pass through the enemy you hit, hitting everything around it
- Balance: Fragmentation Shots no longer self-damage
- Fix: Scavenge Blood and Scavenge Steel will always grant at least 1 health/armour per kill
- Fix: Scavenge items no longer count towards the level item count
- Fix: Revivified minions no longer count towards the level monster count
- Fix: Revivified minions didn't apply vs. player damage modifiers properly
- Fix: certain types of instakill (e.g. in TNT MAP30) could cause crashes
- Fix: Scavenge Lead wasn't actually in the upgrade pool
- Fix: remove Beam from the README, as it's an unfinished upgrade that you can't actually unlock
- Fix: Scavenge Lead would start giving you ammo from other games if you found a backpack
- Fix: hitscan/projectile inference was just completely broken all the time
- Fix: very fast projectiles are now counted as hitscans for e.g. Hideous Destructor
- Fix: upgrades with on-tick effects for the player, such as Infernal Kiln, did not trigger when not using a scoremod
- Fix: the XP scaling setting for scoremods didn't work
- Fix: it is now possible to earn fractional XP rather than rounding down to 0
- Fix: Fragmentation Shots now properly trigger elemental effects

# 0.7.2

- New: README has additional information about using it with LazyPoints and MetaDoom
- Balance: Submunitions do reduced self-damage and have increased blast radius
- Balance: Explosive Shots do reduced self-damage (this can still add up fast with rapid-fire guns, though!)
- Fix: removed some unused cvars and menu entries
- Fix: Explosive Death now actually works, with a blast radius based on the size of the dead thing
- Fix: Submunitions could crash on enemy death

# 0.7.1

- Fix: crash in OnDamageDealt when attacks lacked an inflictor
- Fix: OnDamageDealt didn't properly trigger for some attacks

# 0.7.0

- New: Lightning tree
  - Shocking Inscription paralyzes enemies on hit
  - Revivification brings back slain enemies to serve you
  - Chain Lightning electrocutes entire rooms
  - Thunderbolt smites your target after repeated attacks
- New: Elemental Synthesis upgrades, available only on weapons with two elemental masteries
- New: Submunitions, causing enemies to release explosives when killed.
- New: Scavenge Lead, which causes enemies to drop ammo when killed.
- Change: Life Leech and Armour Leech replaced with Scavenge Blood and Scavenge Steel
  - Rather than restoring on attack, enemies drop restorative items.
- Change: softcap mechanic for elemental effects
  - Elemental stacks no longer have a hard cap, but suffer rapidly diminishing
    returns once they go above the soft cap
  - Some effects are linked to exceeding the cap, e.g. Thunderbolt triggers when
    you have twice as many stacks as the softcap on the target
- Change: Acid Spray sprays less acid, but applies it to all enemies in range
  rather than being able to "run out" of acid.
- Fix: acid applied by Acid Spray inherits the Concentrated Acid level of the
  original acid effect.
- Fix: learning Acid Spray now properly counts as mastering the Acid element
- Fix: damage dealt by DoTs should be less confusing to the "is it a hitscan or
  a projectile weapon" code, hopefully fixing the issue where (e.g.) the rocket
  launcher is misidentified as a hitscan weapon

# 0.6.5

- Change: renamed "Shots" to "Inscription" in elemental upgrades so the names make
  sense with (e.g.) melee weapons.
- Change: Explosive Death now has a brief delay before dealing explosive damage, so
  explosions visibily ripple outwards when a chain reaction is triggered.
- Change: Explosive Death's range now increases more slowly with levels, and is
  based on the radius of the exploding monster; bigger enemies produce bigger booms.
- Change: split the menu code into a separate library, libtooltipmenu.pk3
- Change: you can now pick between 4 upgrades when you gain a level
- Fix: upgrade generation can no longer take unbounded time if you're unlucky
- Fix: upgrade generation can no longer freeze the game if the pool of upgrade candidates is very small
- Fix: Added some missing sprites to the repo (they were still in the pk3 but not versioned)

# 0.6.4

- Change: elemental upgrade prerequisites are now relaxed; basic and intermediate
  upgrades need to be level 2 to unlock the next tier, but higher-tier upgrades
  can now be leveled up to match the tier below.
- Change: WeaponInfo objects can now be rebound to arbitrary weapons even of
  different classes; this has no user-facing effect but may be useful for mod
  integrations.
- Change: internal cleanup of Legendoom integration code.
- Change: redesign of GetInfoFor* API family.
- Change: more documentation on modding/addons/integrations.

# 0.6.3

- Change: internal cleanup of infinite recursion guards. It is now possible for
  upgrades to trigger each other, without causing infinite loops.
- Change: elemental effects will now trigger on AoE upgrades like HE Shots and
  Fragmentation.
- Change: new information about mod compatibility added to README.
- Change: Piercing can now have multiple levels; each level adds another enemy
  it can pierce through.
- Fix: Fragmentation Shots on an AoE weapon like the RL released fragments once
  for every enemy caught in the blast. It now releases fragments only once per
  shot. This is a big nerf to Fragmentation+Piercing, but Piercing is already
  way more powerful than it looks anyways.

# 0.6.2

- New: Explosive Death upgrade causes slain enemies to detonate.
- Change: Acid tree rework
  - Explosive Reaction removed
  - Acid Spray upgraded to mastery; splash radius doubled
  - Concentrated Acid added as intermediate upgrade; increases trigger threshold & damage
  - Embrittlement now instakills sufficiently weakened enemies
- Change: Agonizer now forces the target into pain, duration increases with level
- Fix: VM abort when meleeing certain enemies in Trailblazer
- Fix: Agonizer now has documentation

# 0.6.1

- New: Added hud position and scale settings.
- New: HUD graphics from <sungraphica.itch.io>
- New: HUD settings in the option menu.
- New: HUD colour theming.
- New: HUD mirror settings for positioning in different corners of the screen.
- Fix: HUD is now visible in non-fullscreen HUD modes.
- Fix: HUD is not drawn over the map.

# 0.6.0

- New: Fragmentation upgrade for projectile weapons
- New: Swiftness upgrade for melee weapons
- New: Acid elemental tree
  - Corrosive Shots adds a weak dot that gets more powerful as the target takes damage;
    it works best with slow-firing, high-damage weapons like the rockets and SSG
  - Acid Spray causes surplus acid to splash onto nearby enemies
  - Embrittlement makes acid stacks increase damage taken by enemies
  - Explosive Reaction turns acid stacks into an explosion on death
- New: weapons are limited to 2 elements, and must master the first before adding the second.
- Change: 2 basic levels are now required to unlock intermediate (and likewise for intermediate->master).
- Change: Documentation tweaks.
- Change: Redesign of damage-over-time API to support fractional stacks/durations.
- Change: Fire now applies stacks based on attack damage.
- Fix: Infinite recursion with some upgrade combinations
- Fix: Weakness upgrade could sometimes give enemies damage resistance.
- WIP: Beam upgrade for hitscan weapons
  - currently disabled due to bad interactions with other weapons

# 0.5.2

- Fix: mod didn't actually load due to some last-minute changes.

# 0.5.1

- Fix: build system cleanup. No gameplay changes.

# 0.5

- Change: Poison upgrades overhauled:
  - Poison damage now has diminishing returns (duration still scales linearly)
  - new Weakness upgrades reduces damage dealt by poisoned enemies
  - Putrefaction upgrade is now significantly more powerful
  - new Hallucinogens upgrade makes severely poisoned enemies fight on your side
- Change: internal cleanup to UpgradeBag and Dot APIs
- Fix: crash when carrying upgraded weapons across level transitions

# 0.4

- New: Shield, a very powerful defence upgrade for melee weapons only
- New: Dark Harvest, a melee upgrade that restores health and armour on kills
- New: Bouncy Shots, projectiles that bounce off walls and (eventually) enemies
- New: Agonizer, a melee-only upgrade that increases melee pain chance
- Change: Fire upgrades overhauled:
  - Fire DoT now cuts off at 50% of max HP no matter how much damage it's done
  - new Searing Heat upgrade lowers the cutoff point
  - new Conflagration upgrade makes fire spread between enemies
  - new Infernal Kiln upgrade turns burning enemies into a source of damage/defence buffs
  - Pyre upgrade removed
- Fix: DoTs that do fractional damage per tick now work properly
- Fix: rejecting a level-up with ESC would prevent you from ever gaining new upgrades

# 0.3.2

- Add upgrade registry so that other mods can easily add their own integrations.
- Damage upgrade split into two versions: per player (+5%) and per weapon (+10%).
  Both versions are now guaranteed to add at least 1 damage/level.
- HE rounds now do damage based on original attack damage. Blast radius increases
  more slowly with levels. Self-damage protection added.
- Poison and fire should no longer launch enemies into the sky.

# 0.3.1

- Fixed a category of crash bugs related to dealing or taking damage with no
  weapon equipped.

# 0.3

- Add new upgrades: piercing shots, putrefaction
- Pyre now transfers five stacks/second up to a maximum of the number of stacks
  the victim had when killed
- Tooltips added to options menu
- Fixed a bug where LD effects weren't being handed out properly on level up
- Completely overhauled how weapon upgrades are linked to weapons; the "remember
  XP for missing weapons" option was replaced with a tri-state "upgrade binding
  mode". Please check the options menu for details.

# 0.2

- Builtin upgrades that do not require Legendoom
- Leveling up now gives you a choice of three upgrades from that list
- LD is still supported and weapons can have a mix of builtin and LD upgrades

# 0.1alpha7

- Added that upgrade path back in, along with a lot of settings:
- Which weapons can learn new effects
- Which weapons can replace existing effects
- How many effect slots weapons have
- Whether a weapon's spawn rarity affects its effect pool and/or number of slots

# 0.1alpha6

- Removed the mundane -> legendary upgrade path for weapons.

# 0.1alpha5

- Added "remember missing weapons" option

# 0.1alpha4

- Fixed a crash on level transition

# 0.1alpha3

- Optional Lazy Points integration.
- Fixed a bug where the HUD would draw even when it shouldn't.
- Weapons should now always have info displayed, even if you haven't fired them yet.
- The might also fix the info screen crash for real this time.

# 0.1alpha2

- Turned off some extraneous debug logging.
- Fixed (probably) an occasional crash when closing the info screen.

# 0.1alpha1

Initial release.

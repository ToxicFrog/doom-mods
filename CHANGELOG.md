# 0.6.4

- Change: elemental upgrade prerequisites are now relaxed; basic and intermediate
  upgrades need to be level 2 to unlock the next tier, but higher-tier upgrades
  can now be leveled up to match the tier below.
- Change: WeaponInfo objects can now be rebound to arbitrary weapons even of
  different classes; this has no user-facing effect but may be useful for mod
  integrations.
- Change: internal cleanup of Legendoom integration code.

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

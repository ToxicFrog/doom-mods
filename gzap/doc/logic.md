# Randomizer Logic

To make it easier to add new maps and megaWADs to the randomizer, it uses
automatic logic scans. This often results in more cautious placement of
progression items compared to hand-crafted randomizers, especially when it only
has the initial scan to work from with no tuning.

That logic is detailed here.


## Initial Scan

Based only on the initial scan, the randomizer uses the following logic:

- A level is in logic if:
  - You have the access code for it, **and**
  - You have beaten (level order bias %) of the preceding levels, rounded down, **and**
  - You have at least half of the non-secret weapons, rounded down, that would
    normally be found in that level.
- A check *within* a level is in logic if:
  - You have all the keys in that level, **or**
  - The level only has one key, and the check is the one that would normally hold it

What this means in practice is that while a level is accessible as soon as you
have its access code, the randomizer won't consider most of it in logic until
you have all the keys for the level. This tends to result in a progression where
as soon as a level is in logic at all, you can finish the level completely.


## Logic Tuning

Logic tuning updates the requirements for checks based on actual gameplay.
When playing the game, it emits a record of each check you visit, and what keys
you had when you did so.

Based on this, the logic for each check is adjusted:

- If you found it with no keys, all key requirements are removed from the logic.
- If you found it with keys that are a subset of the current requirements, those
  become the new key requirement.

If you find a check multiple times (i.e. on different playthroughs) using different
keys each time, the logic tuning takes that into account, and correctly handles
cases like "this item can be found with either the blue or red key".

As a megawad receives more tuning, the breadth of what's considered "in logic"
increases to match what you can actually reach.


## Item Pool

The item pool is initially populated with progression and useful items:
- For each level:
  - an access code for the level;
  - an automap for the level; and
  - one copy of each key in the level.
- All weapons, to a maximum of one copy of each weapon per eight levels.
- All other randomized items:
  - By default this means backpacks, powerups, and "big" items
  - The YAML can be used to adjust this as desired

Starting inventory (typically access codes for some starting levels, but this
can also include keys, weapons, automaps, or other things depending on settings)
are then removed from the pool and placed in the player's starting inventory.

The contents of the pool are then scaled by adding or removing filler items
until it exactly matches the number of locations to be filled, based on the
original proportions of filler in the pool.

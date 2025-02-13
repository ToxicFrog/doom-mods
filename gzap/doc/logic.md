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

Logic tuning narrows down the requirements for checks based on actual gameplay.
When playing the game, it emits a record of each check you visit, and what keys
you had when you did so.

Based on this, the logic for each check is adjusted:

- If you found it with no keys, all key requirements are removed from the logic.
- If you found it with keys that are a subset of the current requirements, those
  become the new key requirement.

It does not currently handle the case where multiple sets of keys without a subset
relation can work; for example, MAP19 requires the red key and *either* the blue
or yellow key. <!-- TODO: support this by making the keys a set-of-sets -->


## Item Pool

The item pool is initially populated with progression and useful items:
- For each level:
  - an access code for the level;
  - an automap for the level; and
  - one copy of each key in the level.
- All weapons, to a maximum of one copy of each weapon per eight levels.

The access code and keys for the first level are then removed from the pool and
given to the player as starting inventory.

Any remaining slots are filled with powerups and upgrades. If the number available
doesn't exactly match the number of slots remaining, the quantities are scaled to
retain the original proportions.

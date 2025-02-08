# Randomizer Logic

To make it easier to add new maps and megaWADs to the randomizer, it uses
automatic logic scans. This often results in more cautious placement of
progression items compared to hand-crafted randomizers, especially when it only
has the initial scan to work from with no [refinement](./new-wads.md#refinement).

That logic is detailed here.

## Initial Scan

Based only on the initial scan, the randomizer uses the following logic:

- A level is in logic if:
  - You have the access code for it, **and**
  - You have at least half of the non-secret weapons, rounded down, that would
    normally be found in that level.
- Checks *within* that level are in logic if:
  - You have all the keys in that level, **or**
  - The level only has one key, and that check is the one that would normally hold it

What this means in practice is that while a level is accessible as soon as you
have its access code, the randomizer won't consider it in logic until you have
all the keys for the level. This tends to result in a progression where as soon
as a level is in logic at all, you can finish the level completely.

## Refinement

Refinement narrows down the requirements to find each check. For a given check,
the refinement data is a record of all the times you've picked it up, and what
keys you had when you did so.

Based on this, the logic for each check is refined thus:

- If you found it with no keys, it's in logic as soon as you can enter the level.
- If you found it with keys, it's in logic as soon as you can enter the level
  and have those keys.
- If you found it multiple times with different sets of keys, it's in logic as
  soon as you can enter the level, and your held keys are a superset of any of
  those keysets.

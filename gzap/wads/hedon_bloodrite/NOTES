# Hedon: Bloodrite

## General notes

The logic *should* be valid for both normal and Bearzerker modes; however, the
latter has not been thoroughly tested.

TODO: implement weapon logic for Bearzerker mode as alternate to the main weapon
logic.

Enabling all spawns (`spawn_filter 0` in the YAML) will result in some checks
being completely inaccessible, since they rely on scripts that are only active
on certain difficulties. Doing this is not recommended.

Checks that spawn in mid-game (e.g. from using crafting machines or dropped by
enemies) do not appear on the map regardless of settings. This is a known issue
with event-based locations more broadly, not specific to Hedon, but it is more
obvious here since Hedon has so many of them.

## MAP01: Cold Rock

Power cores aren't permanently deducted from your inventory when used (AP treats
them as keys and returns them to your inventory). Instead, you won't be able to
repair the elevator until you've found two power cores, and will need to have
found three to repair the gate.

The northwest caves, normally reached via the iron key, can also be reached by
opening the timed gate in the outpost and exiting to the pond room. The gate
will close behind you but you can get back into the outpost by swimming through
an underwater tunnel on the west side of the pond.

The wooded area unlocked by offering a moonflower is not considered a secret
for the purposes of logic, but the hidden baths to the east of those woods are.

## MAP02: Plaza

There are several ways to get into the park, all of them in logic:
- use the iron key to flip the park switch in the south guardhouse, as in vanilla;
- use the vine key to enter the alchemist's shop and jump off the balcony;
- use the axe key to enter the north smithy, fall into the well, and follow the
  caves and river clockwise until you enter the library via the ventilation shaft.

The arena fight in the west plaza (that opens an alternate path to the north
plaza when finished) is triggered by entering the west plaza while carrying the
stone key. This means that just having the key is logically sufficient to access
the north plaza.

The arena fight also closes the park gate and the gate connecting the east and
west plazas. You can get back to the east plaza by going north and climbing into
the inn through the window (or using the axe key to open the back door, if you
have it). You can get back to the park using any of the techniques above, but
note that the guardhouse switch is not repeatable; if that's your only way into
the park and you missed any items there, you'll need to reset the level so
that you can use the switch again.

## MAP03: Barracks

A very straightforward map. Note that while the Stone Key unlocks a shortcut
between the sparring room and the firing range, the only thing it's actually
needed for is accessing the north power control room.

## MAP04: Technical Space

Restoring the power is required to access some checks in the starting pumpworks
area, but opening the rest of the level only requires the toolkit.

Reaver Tiati leaves some items behind when she exits via the portal. This is
triggered by exiting the Great Forge in the direction of the Portal Chamber
while carrying the Iron Key. (It is possible to skip this trigger by toggling
the key off, which gets you an easter egg, but there are no checks in it and it
results in a game over, so save before attempting this.)

The iron and mithril ores you can mine out of the walls throughout the
northwestern areas of the level are checks, and require the pickaxe.

The upper caves, normally accessible using the Earth Key, can also be reached
using the Axe Key via the maze, which connects the magma chamber to the upper
caves.

The trigger to open the east hall is forging the mithril gear on the anvil. Note
that you don't actually need to get a gear from it; it's the process of forging,
not the item you get, that causes the door to open. However, you *will* need the
gear to actually exit the level; Zan will refuse to arm the explosives otherwise.

### Crafting machines

The fabrication machines in the Great Forge and the rooms attached to the North
Hall can be used to produce checks. The machines and their requirements are
listed here.

- Dwarven Forge
  - Iron Ore -> Iron Ingot (repeatable four times for four different checks)
- Repair Bay
  - Iron Ingot -> Iron Key
- Great Forge
  - Mithril Ore ×5 -> Mithril Ingot
  - Gear Mould + Mithril Ingot -> Filled Gear Mould
  - Filled Gear Mould -> Mithril Gear
- Mould Forge (not in Bearzerker mode)
  - Iron Ingot -> Fragfire Can
  - Iron Ingot -> Spikes
  - Iron Ingot + Red Crystal ×3 -> Boltmag
- Mould Forge (Bearzerker mode)
  - Iron Ingot -> Axe
  - Iron Ingot + Red Crystal ×6 -> Fire Hammer
  - Iron Ingot ×8 -> Great Axe

Inputs are infinitely reusable once you find them through AP, so (e.g.) one
Iron Ingot is sufficient to get the Iron Key, Fragfire Can, and Spikes checks.
The Iron Ore smelter, like the power core checks in MAP01, requires you to find
multiple Iron Ore items to smelt higher numbers of Iron Ingots.


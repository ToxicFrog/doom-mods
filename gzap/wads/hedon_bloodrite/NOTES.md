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

Hedon contains many key items that are used up to unlock areas or create new
items, such as the power cores in MAP01, alchemy supplies in MAP02, and ores and
ingots in MAP04. AP treats these as keys, which means that they cannot be
expended; if you do something that uses them up, AP will return them to your
inventory as soon as it notices, and you can force it to notice by toggling them
off and on from the inventory screen. Instead, some triggers now require you to
have found multiple copies of these keys. These changes are noted below.

## MAP01: Cold Rock

Repairing the elevator now requires you to have found two power cores, and
repairing the gate requires three.

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

The scribe's table in the library can be used (with Mortars of Earth Pigment and
Bowls of Scribe Embers) to scribe various scrolls. It will accept at most two
of the former and three of the latter (the most that you can find on this map in
vanilla play); to spend more you need to go to MAP05, Grove, and use the table
near the entrance there.

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

The Iron Ore -> Iron Ingot smelter requires you to have found up to four Iron
Ore items to get all four Iron Ingot checks. None of the others are repeatable;
using them a second time will either produce the vanilla item or a non-usable
key placeholder.

## MAP05: Grove

As in MAP02, the scribe table in the Library can be used to convert Earth
Pigment and Scribe Embers into scrolls (and thus checks). The logic assumes that
your first two pigments and three embers will be spent on MAP02, and thus won't
let you use this table unless you've already gotten the checks from MAP02, *or*
have enough excess that writing scrolls here won't prevent you from doing so,
as an anti-softlock measure.

Once you open the gate with the Mithril Gear, most of the map is open to you
immediately. Reaver HQ to the east appears locked, but you can open the main
door by shooting the button through the window; if you have no ranged weapons,
you can also swim downstream and enter by breaking the glass in the submerged
ruins.

In addition to the doors you can open with the Book of Earth, there are a number
of places you can use it for other effects. The only ones that actually contain
checks are the healing crystals you can grow outside the Great Stump, and the
secret in the Library.

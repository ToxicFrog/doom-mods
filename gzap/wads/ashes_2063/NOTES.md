# Notes for players

Requires [Ashes 2063 Enriched Edition v2.3](https://www.moddb.com/mods/ashes-2063/downloads/ashes-episode-1ashes-2063pk3-only-v22).
This version includes both Ashes 2063 proper and the four-episode Dead Man Walking expansion.

## Known issues

The .45 Revolver appears in the pool as a progression item even though you start
with one and finding it in the pool changes nothing. Turning on automatic weapon
logic in the YAML will make it logically required for most maps.

The NPC at the start of Fissile Empire, when killed, will drop both a blue
keycard (which you can't pick up) and a check for the blue keycard (which you
can).

All random food is replaced with `FoodTin1`, and all random junk is replaced
with `JUNKgear`. This results in a slight increase to the amount of money
available to the player but also makes handling the logic a lot easier. Future
versions may properly handle these as `random food` and `random junk`, but that
requires additional features in the scanner.

## General information

### Money

Money is `small-token`, or `medium-token` for the $100 collectibles.

Breakables that sometimes drop money (trash bags, trash cans, and small boxes)
are not presently randomized and have their usual drop rates.

### Shops and dialogue

Items received from dialogue are not yet checks. (I want them to be in the
future, but didn't want to delay the 0.9.0 release for it.) This means:
- all purchased ammo/stims/meds
- buying the silver key in MAP00
- receiving the Briefcase from Smiley or the Blue Key from the bartender in MAP03
- winning the bet against Fortune for the Classic Shotgun in DAM1
- trading the briefcase for the armour, backpack, or Michonne Ultra in MAP06
- printing the security pass in MAP08
- buying the upgraded machinepistol in MAP52
- receiving the blue key at the entrance to MAP54 via dialogue

That said, the following in-game spawns *are* checks:
- ammo spawned by BulletFarm machines in MAP01 and MAP07
- receiving the blue key at the entrance to MAP54 via violence

### Weapons

Progressive weapon support is not yet implemented, so rather than include all
weapon variants, all upgradeable weapons are replaced with their fully-upgraded
forms -- all pump-action shotguns are the Classic Shotgun (which you normally
get from Fortune if you win the bet in DAM1) and all machinepistols are the
Michonne Ultra (which you normally get from Rigs in MAP06).

Pipebombs are both a weapon and their own ammo; as a result they are `big-ammo`
rather than `weapon`, do not participate in weapon logic, and are never
logically required.

## Map-specific information

### MAP00: Garage Punk

The NPC outside the shooting range will sell you a key, but buying it is not a
check and the key itself is not actually needed; you can get into the range via
a jump from the ledge outside the ruined apartments to the north.

### MAP01: Outskirts

The BulletFarm machine near the storage room can be activated to spawn three
`fortyfiveammo`. TODO: event these.

### MAP03: The Wall

No item is needed to exit the map -- just make sure you don't have the radio in
your inventory, talk to Smiley, and say that you're ready to go.

Getting the blue key from the bartender requires having the briefcase in your
inventory; otherwise he'll just tell you to talk to Smiley instead.

This map contains several unreachable items. AP will not randomize them and they
exist solely for cosmetic effect.

### DAM1: Those Dam Raiders

Winning the race against Fortune is not a check, so feel free to take your time.

### MAP06: Terminus

The pit fights are not randomized and there are no checks associated with them.

Trading the briefcase for a Michonne Ultra is not supported in AP. Trading it
for armour or a backpack is, however. You can do both by trading for one, then
using the AP inventory menu to summon another briefcase (by turning it off and
on again) and talking to him again.

### MAP07: The City

Cat's Cradle Elevator requires having the blue key in your inventory; it's a
scripted event that triggers not when you pick up the key but when you walk
through the nearby rooms while holding it.

The War-Mart building has two BulletFarms in it that can be activated -- the
north one produces `fortyfiveammo`, the south one `shotgunAmmo`, three each.

### MAP08: Damage Control

The bunker access code is 1221. Fiddle around in the dialogue tree for a bit and
it should become an option even if you haven't gone to MAP07 and heard the
transmission yet.

### MAP51: Dead Man Walking

The "office building" region is the unnamed building north of Jojo and War Games
that you need the blue key to access.

### MAP52: The Bunker

Nothing you can get from the quartermaster is a check, so unless you want to
buy something, there's nothing to do here except grab some stuff from the table
near him and leave.

### MAP54: Fissile Empire

You can receive the key from the guy at the entrance by talking to him, but the
actual check is triggered by killing him (which will cause him to drop the key
even if he's already given you one).


# Notes for logic developers

## Weapons

For the most part, A2063 weapons are just normal weapons. The exceptions are:
- pipebombs; the ammo type (PipeAmmo) is never placed in-world, instead
  picking up a pipebomb gives you one PipeAmmo as well
- pump-action shotguns; the weapon is never placed in the world, only a
  PumpySpawn, which checks if you have the upgraded pumpaction2 and decays
  into ammo if so (otherwise you could end up with both plain and upgraded
  versions in your inventory)
- machinepistols; this works the same as the shotguns, except there are two
  upgraded versions, ingram2 and ingram3

Someday we will have progressive item support, in which case there will be two
progressive shotguns and three progressive machinepistols. Until then, we take
the simplifying approach of just giving the player the fully upgraded version.

In normal play, you get the pumpaction2 (actually a PumpgunBuild2, which when
picked up deletes the pumpaction and replaces it with a pumpaction2) by
talking to Fortune, accepting her bet, then beating her in a race to the
bottom of DAM1.

You get the Ingram3 in MAP06, Michonne Circle, by delivering the briefcase to
Rigs and then choosing "you make weapons?" when he offers you a reward, as
long as you have the Ingram in your inventory.

The Ingram2 is Dead Man Walking only, found by talking to the quartermaster in
MAP52 and buying a silencer from him.

## Money

Money is "Chips" internally, and can be found lying around or by breaking CONT items.

Generally speaking it's spent by talking to NPCs, who will have a Strife dialogue
node with `giveitem` and `cost` directives. These aren't currently checks. It
would be nice if we could make them checks! But then we also need smallkey logic.

One workaround is to make chips map-scoped multikeys, which means as soon as the
player has enough money to buy the most expensive thing in a map they can buy
everything in the map...as long as there's enough chips in the map itself, which
is by no means guaranteed.

### MAP00

thug outside firing range sells silver key (BlueSkull) for $60. This is
actually optional because you can climb up the derelict apartment block to the
northeast, strafejump across to the balcony, and enter via the ventilation.

### MAP03

Smiley sells items:
- firstaid for $100
- shotgunammo for $80
- fortyfiveammo for $30
Also, if you have the QuestRadio, he'll give you $100 and the QuestBriefcase for it.
Once you've done that, you can also talk to him to exit the map.

Barkeep Kurt sells food:
- BarWater for $20
- BarFood for $50
If you have the QuestBriefcase, you can ask about work and he'll put you in touch
with Fortune and give you the BlueCard.

Bagman, the shady trader, sells drugs and ammo:
- REGEN for $250
- PURGE for $200
- 9mm mag for $100

Fortune offers you a bet. If you accept it you get the "bet accepted" flag which
is checked in DAM1.

### DAM1
If you didn't accept the bet you get $100 for clearing the level. If you did,
AND you beat Fortune to the end, you get $100 and an upgraded shotgun.

### MAP06

Rigs sells:
- napalmammo for $300
- ninemilammo for $120
If you have the QuestBriefcase (and Smiley is alive) he'll also offer you a choice
of armorcombat or backpack; ask him about making weapons and show him an ingram
and he'll upgrade it to the Michonne Ultra.

The gun seller sells:
- junkermusket for $200
- slugammo for $140
- shotgunammo for $80
- fortyfiveammo for $30

Dealer sells:
- regenstimpack for $250
- purgestimpack for $200
- powerrage for $300

Bartender Violet sells:
- BarWater for $10
- BarFood for $30

There's also a place where you can bet on pit fights.

### MAP08

Interacting with the security computer is needed to open most of the doors and
also prints the blue access card for you. This is given to you via a DIALOG
`giveitem` directive, so it will require some testing to figure out how to
capture it as an event. Looks like it spawns at (0,0,0) and then we
CallTryPickup, so probably we want to make sure the PickupDetector is always in
head position and handle it there after introducing a new event type for it.

### MAP52

QM sells:
- ninemilammo for $100
- shotgunammo for $80
- fortyfiveammo for $30
- firstaid for $120
- purgestimpack for $70
He'll also buy your sawn-off for $200, and sell a silencer for $200 -- if you
have RJToken_HaveIngram (it doesn't check the ingram directly!)

### MAP54

The insane idiot sells:
- armorcombat for $200
- ammopack for $200
- napalmgun for $200

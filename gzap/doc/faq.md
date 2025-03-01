# gzArchipelago FAQ

## Help!

### World generation says "no more spots to place items"!

This means the generator got into a state where it couldn't figure out where to
place progression items in a way that keeps the game winnable. This is most likely
to happen with newly generated logic files or ones with "basic" support, and can
usually be resolved by retrying a few times.

Setting the `level order bias` option too high can also cause this.

If it's happening on a tuned ("full" or "complete" support) logic file, or if
happens *every* time, please report it.

### I got partway through a level and now I'm stuck!

Try a different level -- the randomizer may require you to visit one level to get
some items, then leave and visit a different level without finishing the first.
You can open the level select menu at any time, not just between levels.

You can also die and respawn; you'll reappear at the start of the level, but the
level as a whole won't reset. This can be useful if you've gotten stuck in a pit
or something but there's other parts of the level you want to visit before you
leave.

### I keep finding armour/powerups/etc but nothing happens!

Rather than being given to you directly, these go into a special "randomizer inventory"
that you can summon items from at any time. Open the inventory menu and choose the
item you want. This helps mitigate issues like being given an invincibility sphere
just before you leave the level, or a level balanced around having hazard suits
getting all of them shuffled into other levels.

Note that items created this way are dropped at your feet; you won't pick them up
until you take a step.

### I can't open the level select or inventory menu!

Did you remember to [bind those controls](./gameplay.md)?


## Compatibility

### Can I play this singleplayer?

Yes! Generate the game as normal, then load the `.zip` that Archipelago generates
as your last mod in gzdoom. All checks will be resolved locally without needing
a separate game host.

### Can I play this single-world with netplay?

Maybe. I've tried to make the code netplay-friendly but it's completely untested.
If it does work, check state and randomizer inventory will be
**fully shared between players**, and using the level select will gate all players
to the selected level -- if you want to play separate levels you actually want
multiworld without netplay.

### Can I play multiworld?

Yes. Once the APWorld is installed, the client will show up in the Archipelago
launcher. Start the client *first* and it will tell you what extra arguments
to launch gzdoom with.

### What megawads does this have builtin support for?
### What maps/mods is this compatible with?
### Will this work with...?

See the [table of supported wads](./support-table.md) and the
[compatibility notes](./compatibility.md).

### How do I add support for a new WAD?

See [adding new WADs](./new-wads.md).


## Project Rationale

### How is this different from existing actor randomizers like DRLA/MetaDoom/Doom Infinite/etc?
### How is this different from existing level randomizers like Map Order Shuffle?

The [Archipelago FAQ](https://archipelago.gg/faq/en/#what-is-a-multiworld) has
a good explanation of what multiworld randomizers do.

### How is this different from [Archipelago's existing Doom support](https://archipelago.gg/games/DOOM%201993/info/en)?

In two major ways.

Firstly, AP's support for Doom (and Doom 2 and Heretic) is based on a custom fork
of Crispy Doom, called [APDoom](https://github.com/Daivuk/apdoom). If you are looking
for a mostly-vanilla Doom experience, it's quite polished and I highly recommend it.
However, if you're looking for a non-vanilla experience, it doesn't support DECORATE,
zscript, etc.

On top of that, adding support for *new* WADs to APDoom is difficult: you need to
use a separate program to scan the WAD, then compile a custom version of APDoom
itself incorporating the resulting info.

My goal with gzArchipelago was to make it possible to play Archipelago multiworld
with gzDoom mods, and make it easy to integrate new WADs via a scanner built into
the mod itself.



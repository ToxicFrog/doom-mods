# gzArchipelago FAQ

## Help!

### World generation says "no more spots to place items"!

This means the generator got into a state where it couldn't figure out where to
place progression items in a way that keeps the game winnable. This is most
likely to happen with newly generated logic files or ones with "basic" support,
and can usually be resolved by retrying a few times.

If it happens consistently, you have a few options for reducing constraints on
the randomizer:
- Adding more `starting_levels` will give it more places to put early items, as
  will turning on `start_with_keys` and `allow_secret_progress`
- Turning down `level_order_bias`, `local_weapon_bias`, and `carryover_weapon_bias`
  will let it move more items to later spheres (but also make the game harder)
- Adding more categories to `included_item_categories` will give it more locations
  to put things at (but also add more filler to the item pool)

You can also turn on `pretuning_mode` and play through the first few levels to
generate a partial logic file, which in most wads will give it enough information
about early-game item placement to get it unstuck even without `start_with_keys`.

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


## Customization

gzArchipelago has a lot of customization options, most of which are accessible
via the Archipelago YAML (and documented in the comments there) or via the in-game
settings (and documented in tooltips). This section is for "hidden" settings that
aren't, and non-obvious information.

### What gets randomized?

By default, all keys, weapons, powerups, armour, and soulspheres/megaspheres.
Additionally, an "access key" for each level is added to the item pool, which
you must find before you can enter that level. Automap locations are added to
the location pool; the randomizer will also either start you with all automaps
or add one automap per level to the item pool, depending on settings.

Settings in the YAML can be used to add or remove items from randomization, if
you want more or less than the defaults.

### What's the win condition?

By default, to clear all levels included in the randomized game. You can set
this to a lower level in the YAML.

### Can I bind hotkeys for inventory items?

Inventory items can be dispensed using the `ap-use-item:<item-name>` netevent,
which lets you bind hotkeys for them. The following console commands will bind
`b`, `h`, and `m` to dispense backpacks, soulspheres, and megaspheres:

    bind b "netevent ap-use-item:Backpack"
    bind h "netevent ap-use-item:Soulsphere"
    bind m "netevent ap-use-item:Megasphere"


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



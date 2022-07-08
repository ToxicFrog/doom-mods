# libtooltipmenu - tooltips in gzdoom option menus

This is a small library for display tooltips in option menus. It provides a convenient way to display in-game information about mod settings (or anything else you might use an option menu for), without crowding the menu with lots of `StaticText` entries. The tooltips can be written directly in the MENUDEF and require no special handling in your mod's code.

It is a single file containing two classes, which can be either loaded as a separate pk3 (available on the [releases page](https://github.com/ToxicFrog/laevis/releases)) or simply copied into your mod wholesale.

For an example of this library in use, check out [Laevis's MENUDEF](https://github.com/ToxicFrog/laevis/blob/main/laevis/MENUDEF).

## API

N.b. tooltips will work with *any* selectable menu item, including new ones you add yourself, but for convenience these examples mostly use `Option`.

### Loading the library

The library provides `TF_TooltipOptionMenu`, a drop-in replacement for gzDoom's `OptionMenu`, which you can load with the `class` directive in your MENUDEF:

```
OptionMenu "KittenOptions"
{
  class `TF_TooltipOptionMenu`
  ...
}
```

If you do nothing else, this will behave like a normal `OptionMenu`; you must use the `Tooltip` menuentry type to add tooltips.

### Adding tooltips

To do this, just follow the menu item with a `Tooltip`:

```
Option "Enable Kittens", "sv_kittens", "YesNo"
Tooltip "Whether or not to enable kittens."
Color "Kitten Eye Colour", "sv_kitten_eyes"
Tooltip "Default eye colour for kittens. Some kittens may ignore this setting."
```

For multiline tooltips, you can use `\n`, or you can use multiple `Tooltip` directives in sequence:

```
Option "Kitten Energy Level", "sv_kitten_energy", "KittenEnergyOption"
Tooltip "How energetic kittens should be."
Tooltip "\c[CYAN]Quiet:\c- kittens will mostly sleep."
Tooltip "\c[CYAN]Frisky:\c- kittens will scamper around and get into trouble, but not directly interfere with you."
Tooltip "\c[CYAN]Full Kitten:\c- kittens will actively climb your legs."
```

As you can see, they also support the same escape sequences as `Print`.

### Sharing tooltips between menu items

It's sometimes the case that you have multiple related menu items that all need the same tooltip. In that case, just list them all out and then add the tooltip:

```
StaticText "Additional Spawns"
Option "Adult cats", "sv_kitten_grownups", "YesNo"
Option "Ferrets", "sv_kitten_ferrets", "YesNo"
Option "Crows", "sv_kitten_crows", "YesNo"
Tooltip "Whether to spawn various cute non-kitten things in addition to kittens."
Tooltip "These may not have as many behaviours implemented as kittens, but you can still pet them."
```

The tooltip(s) will stick to all the menu items immediately above them that do not already have tooltips.

### Disabling tooltips for some items

You may want to have some items with no tooltips at all, followed by items with tooltips. To prevent the tooltips from sticking to all of them, you can insert a blank tooltip:

```
// Should be self-explanatory, so no tooltips.
Command "Reboot gzDoom", "restart"
Command "Exit gzDoom", "exit"
Tooltip "" // Clear tooltip
Command "Twirl!", "spin180"
Tooltip "Turns the player around."
```

The tooltip `Turns the player around` will stick only to `Twirl!` and not either of the earlier tooltips. The blank tooltip skips tooltip rendering entirely, rather than just rendering an empty tooltip; if for some reason you really want it to render an empty tooltip, use `Tooltip " "` instead.

## License

This library is released under the MIT license. Full details are in [COPYING](./COPYING.md), but the short version is: free for

## Future Work

- support for arbitrary size and positioning of tooltips via `TooltipConfig` directive
- support for drawing background textures on tooltips

# libtooltipmenu - tooltips in gzdoom menus

This is a small library for displaying tooltips in gzDoom menus (both ListMenus and OptionMenus). It provides a convenient way to display in-game information about mod settings (or anything else you might use an option menu for), without crowding the menu with lots of `StaticText` entries. The tooltips can be written directly in the MENUDEF and require no special handling in your mod's code, or inserted at runtime as part of dynamic menu creation. They support `Print` colour/format escapes and `LANGUAGE` localization.

It consists of three ZScript files, which can be either loaded as a separate pk3 (available on the [releases page](https://github.com/ToxicFrog/doom-mods/releases)) or simply copied into your mod wholesale. (In the latter case, don't forget to rename the classes to avoid conflicts with other mods that use it -- see the end of tihs file for details.)

For an example of this library in use, check out [Gun Bonsai's MENUDEF](https://github.com/ToxicFrog/doom-mods/blob/main/gun-bonsai/MENUDEF). If you have questions, comments, or bug reports, use the Github issues system or post in the [ZDoom forums thread](https://forum.zdoom.org/viewtopic.php?p=1233646).

## MENUDEF API

N.b. tooltips will work with *any* selectable menu item, including new ones you add yourself, but for convenience these examples mostly use `Option`.

### Loading the library

The library provides `TF_TooltipOptionMenu` and `TF_TooltipListMenu`, drop-in replacements for gzDoom's `OptionMenu` and `ListMenu`, which you can load with the `class` directive in your MENUDEF:

```
ListMenu "KittenMainMenu"
{
  class TF_TooltipListMenu
  ...
}

OptionMenu "KittenOptions"
{
  class TF_TooltipOptionMenu
  ...
}
```

If you do nothing else, these will behave like the built-in gzDoom menu types; you must use the `Tooltip` menuentry type to add tooltips.

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

As you can see, they also support the same escape sequences as `Print` (and `$` localization directives, too).

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

### Configuring tooltip position

The default is to place tooltips in the top left corner, with a maximum width of ⅓ of the screen.

You can change the size and position of the tooltips with the `TooltipGeometry` directive:

```
// Arguments: X, Y, width, horizontal margin, vertical margin, scale
// Place tooltip in the bottom center with really fat margins and 50% larger
// than normal.
TooltipGeometry 0.5, 1.0, 1.0, 4.0, 2.0, 1.5
```

`X` and `Y` determine the positioning of the tooltip, as a proportion of screen size; `0.0, 0.0` places the tooltip in the top left, `1.0, 1.0` in the bottom right, and `0.5, 0.5` in the center of the screen.

`width` determines the maximum width of the tooltip, also as a screen proportion; a tooltip longer than this will be wrapped to span multiple lines.

The `margin` arguments determine the amount of blank space allotted surrounding the actual text of the tooltip; horizontal is in multiples of em width, and vertical in multiples of line height.

`scale` determines the text scale. The default font size is based on CleanYFac_1 and gives a font size comparable to the default option menu; scale values other than 1.0 will shrink or enlarge the font accordingly (and the background image, it given with `TooltipAppearance`, will be scaled to match).

You can use as many `TooltipGeometry` directives as you want; each one will affect only the tooltips after it, so you can use this to position different tooltips at different locations or with different sizes. If you want to override only some of the settings, passing `-1` for a setting will leave it unchanged, so (e.g.) `TooltipGeometry -1, -1, -1, 0.0, 0.0, -1` would zero out the margins without affecting the size or position.

### Configuring tooltip appearance

The default is white text, using `newsmallfont`, with no background.

You can use `TooltipAppearance` to change the font, colour, and background of the tooltips:

```
// Arguments: font name, colour name, texture name
// Make tooltips pink against a background of a box of shotgun shells.
TooltipApperance "newsmallfont", "pink", "SBOXA0"
```

The font and colour will be resolved with `GetFont` and `FindFontColor`. The texture supports animation and will be scaled to fit the tooltip, so it's recommended to choose something that will still look acceptable when stretched or squished into odd shapes. If you want a simple black background with antialiased edges, libtooltipmenu ships with one, called "TFTTBG".

Like `TooltipGeometry` this can be specified multiple times to apply different settings to different tooltips. To leave a setting unchanged, use `""`, e.g. `TooltipAppearance "", "blue", ""` to change the font colour and nothing else.


## Dynamic Menu ZScript API

This API is for adding tooltips to menus created at runtime. The basic idea is:

- Subclass `TF_TooltipOptionMenu` or `TF_TooltipListMenu`
- In its `Init(parent, descriptor)` function, call `super.InitDynamic()` rather than `super.Init()`
- Call `TooltipGeometry()` and `TooltipAppearance()` to configure tooltips
- Add your menu entries to `self.mDesc.mItems`
- Call `PushTooltip()` to add tooltips
- Create a MENUDEF entry using your subclass and including no menu items
- Activate the menu at runtime with `Menu.SetMenu(menu_name)`

The following sections go into more detail; for an example of it in use, see Gun Bonsai's [GenericMenu](https://github.com/ToxicFrog/doom-mods/blob/main/gun-bonsai/ca.ancilla.bonsai/menu/GenericMenu.zs) and [WeaponUpgradeMenu](gun-bonsai/ca.ancilla.bonsai/menu/StatusDisplay.zs) classes.

### Class inheritance and initialization

`InitDynamic()` handles initializing the tooltip configuration structures and clearing the descriptor's item list so that items from previous iterations of the menu don't re-appear.

```
class KittenListMenu : TF_TooltipOptionMenu {
  override void Init(Menu parent, OptionMenuDescriptor desc) {
    super.InitDynamic(parent, desc);
    ConfigureTooltips();
    BuildMenu();
  }
}
```

### Tooltip configuration

`TooltipGeometry()` and `TooltipAppearance()` take the same arguments as the MENUDEF entries of the same name, and behave the same way, affecting all tooltips after them.

```
  void ConfigureTooltips() {
    TooltipGeometry(0.5, 1.0, 0.9);
    TooltipAppearance("", "", "TTIPBG");
  }
```

### Adding tooltips and menu items

`PushTooltip(text)` adds a tooltip to the preceding menu item. As with the `Tooltip` MENUDEF directive, it supports print escapes and `LANGUAGE` lump references. If you want to attach a tooltip to multiple items, you can specify a second argument indicating how many to attach to.

```
  void BuildMenu() {
    mDesc.mItems.Push(new("OptionMenuItemCommand").Init("$TWIRL_MENUITEM", "spin180"));
    PushTooltip("$TWIRL_TOOLTIP");
    mDesc.mItems.Push(new("OptionMenuItemCommand").Init("Restart", "restart"));
    mDesc.mItems.Push(new("OptionMenuItemCommand").Init("Exit", "exit"));
    PushTooltip("Do these really need descriptions?", 2);
  }
```

### Create and activate the menu

You still need an empty MENUDEF entry so you can activate it:

```
OptionMenu "KittenListMenu"
{
  class KittenListMenu
  Title "Kittens!"
}
```

Once you have that, you can just use the menu API to activate it by calling `Menu.SetMenu("KittenListMenu")`, which will automatically call your `Init()` function.


## Renaming to avoid conflicts

If you don't want to add the pk3 as a separate dependency and instead want to copy libtooltipmenu into your own mod, you should rename the libtooltipmenu classes to avoid conflicts with other mods that use it. The classes you'll need to rename are:

- `Tooltips.zsc`: `TF_Tooltip`, `TF_TooltipHolder`, `TF_TooltipItem`, `TF_TooltipGeometry`, `TF_TooltipAppearance`
- `TooltipOptionMenu.zsc`: `TF_TooltipOptionMenu`, `OptionMenuItemTooltipHolder`, `OptionMenuItemTooltip`, `OptionMenuItemTooltipGeometry`, `OptionMenuItemTooltipAppearance`
- `TooltipListMenu.zsc`: `TF_TooltipListMenu`, `ListMenuItemTooltipHolder`, `ListMenuItemTooltip`, `ListMenuItemTooltipGeometry`, `ListMenuItemTooltipAppearance`

The class names starting with `TF_` you can just change to have another prefix, e.g. `MyCoolMod_`. Class names starting with `ListMenuItem` or `OptionMenuItem` *need to start with those* for interoperability with the MENUDEF system; for those you're best off adding an infix (e.g. `ListMenuItemMyCoolModTooltip`), and then referencing them in the MENUDEF as `MyCoolModTooltip` et al.

You should be able to do this with two global search-and-replaces on these files, without any false positives:

- `TF_` → `MyCoolMod_`
- `ItemTooltip` → `ItemMyCoolModTooltip`

## License

This library is released under the MIT license. Full details are in [COPYING](./COPYING.md), but the short version is: do whatever you want with it (including commercial and closed-source projects and derivative works) as long as you don't try to pass it off as your own work.

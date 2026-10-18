# Custom code in apworlds

Some WADs require custom code to function properly, either python code in the
apworld, or zscript code in-game. UZAP has provisions for adding such code on a
per-apworld basis.

This is a very new feature; if it doesn't support some aspect you need, please
let me know.

## Python

If the apworld contains a file named `custom.py`, it will be loaded immediately
after the apworld options (`Options.py`) are initialized. The apworld will look
for a function called `custom_options` in it, and call that function, passing it
the Options dataclass as the first argument, and all individual option types as
trailing kwargs.

`custom_options` thus has a chance to modify the dataclass itself (e.g. to add
or remove options entirely), and to modify individual options (e.g. to change
defaults or limits).

Examples:
- [The Adventures of Square](../wads/the_adventures_of_square/custom.py)
  disables persistent mode and hides the option to prevent the player from
  turning it back on, since turning it on makes the wad nonfunctional
- [Time Tripper](../wads/time_tripper/custom.py) pre-populates the player's
  inventory with weapons that otherwise are given by scripts (which may not work
  in AP depending on the player's settings)
- [BTSX E2](../wads/btsx_e2/custom.py) changes the defaults for some settings
  and adds useful advice from the logic maintainer to several more

## ZScript

If the apworld contains files named `ap_scripts.zs` and/or `ap_mapinfo.txt`,
they will be included in the generated PK3 that gets loaded by the game. The
former will be included from the top-level `ZSCRIPT` lump and the latter from
the top-level `MAPINFO`. This allows you to both include arbitrary zscript code,
and to register event handlers.

At the moment the only example of this is for the (work in progress) Hedon
apworld: [zscript](../wads/hedon_bloodrite/ap_scripts.zs),
[mapinfo](../wads/hedon_bloodrite/ap_mapinfo.txt). It's used there to change the
behaviour of power crystals in the first map.
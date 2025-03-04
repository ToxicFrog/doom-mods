# Unreleased

- Fix:
  - Signed/Unsigned comparison warnings due to using uints to iterate int-sized collections.
  - Tooltips that are wider/taller than the screen will stick to the left or top edges
    rather than failing to render entirely.

# 0.2.4

- Fix:
  - `SelectedItem` and `DefaultSelection` were not handled properly, resulting in a default selection further down the menu than intended for some menus.

# 0.2.3

- Fix:
  - `PushTooltip("")` has the same behaviour as `Tooltip ""` in MENUDEF, omitting the tooltip instead of installing an empty one.

# 0.2.2

- New:
  - support for `ListMenu` menus.
  - support for tooltips in dynamically generated menus. This was always possible, but gross; now there's an actual API for it.
  - README now includes more detailed instructions on how to incorporate this into a mod without conflicts.

# 0.2.1

- Fix: tooltips are now localized (via the LANGUAGE lump) before being formatted and rendered. Fix contributed by <https://github.com/idiotbitz>.

# 0.2.0

- Fix: tooltip font size now automatically scales based on screen resolution
- New: `TooltipGeometry` allows specifying a font scaling factor

# 0.1.3

- Fix: intermitten array index out of bounds crash when opening the menu

# 0.1.2

- Fix: closing and reopening a menu no longer causes the tooltips to vanish forever

# 0.1.1

- New: TooltipGeometry directive to set tooltip size and position
- New: TooltipAppearance directive to set font, colour, and background

# 0.1.0

- Initial release

# 0.2.4

- Fix: warning about malformed colour format in Indestructable.zsc

# 0.2.3

- Fix: pistol start/death exit compatibility
  - Pistol-starting a level now gives you extra lives as if you had started a new game
- Fix: Universal Pistol Start no longer causes Indestructable to stop working
- Fix: `indestructable_report_lives` netevent is now properly emitted on startup

# 0.2.2

- Fix: remove leftover debugging message

# 0.2.1

- New: options for different visual effects when the mod activates, as well as disabling VFX entirely.
- Fix: correctly display starting lives even when you have unlimited

# 0.2.0

- New: more configuration options (and some of the existing ones now behave slightly differently)
- New: other mods can listen for `indestructable_report_lives` netevents to get updates on Indestructable's internal state
- New: other mods can add/remove lives by emitting an `indestructable_adjust_lives` netevent

# 0.1.2

- Change: fancier tooltips using libtooltipmenu-0.1.1

# 0.1.1

- Fix: removed some stray debug logging
- Fix: mod would sometimes stop working entirely on level transition
- Fix: messages from the mod now properly display in the HUD
- Fix: the "you have X lives" message on level entry is no longer overwritten by the autosave message

# 0.1.0

- Initial release

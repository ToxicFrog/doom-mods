# 0.3.0

⚠ This update breaks save, setting, and netevent compatibility! ⚠

- New:
  - Menu strings and in-game messages are now stored in a `LANGUAGE` lump and
    can be translated.
  - Optional compatibility with death exits and pistol start mods (see the
    `Compatibility` section in the options menu).
  - Awarding of extra lives on level clear can now be made contingent on 100%
    kills, 100% secrets, either, or both.
  - Optional granting of bonus lives based on damage survived, similar to how
    the Gun Bonsai upgrade `Indestructable` works.
  - Gun Bonsai integration is now explicitly turned on with a configuration option
    rather than implicitly turned on based on your other settings. See the
    `Compatibility` section.
- Changed:
  - `Min lives on boss kill` setting removed
  - `Max lives on boss kill` and `max lives on level clear` settings combined
    into one `max lives` setting
  - `Lives on new game` and `min lives on entering level` settings ignore `max lives`
  - Mod interoperability changes:
    - `indestructable_report_lives` netevent renamed `indestructable-report-lives`
    - `indestructable_adjust_lives` netevent renamed `indestructable-adjust-lives`,
    and the API changed
    - New `indestructable-set-lives` netevent
- Fix:
  - Indestructable buff timer no longer counts down when the player has the
    `TOTALLYFROZEN` flag set. In particular, this means that it won't expire
    while the player is frozen by mods like Gearbox.
  - Extra lives are not consumed if the player is using god mode or has the
    buddha-nature, even if it looks like they are about to die.
  - Softlocks should no longer happen when Indestructable triggers at the same
    time as Gun Bonsai's `Swiftness` upgrade.
  - Multiplayer games with more than 8 players are now (theoretically) supported,
    if the underlying engine supports that.
  - Players joining a multiplayer game partway through a level should get some
    extra lives as if they had started a new game.
  - Lives for clearing a level are now assigned as you exit the cleared level,
    not as you enter the new one, fixing some weird edge cases.
  - Improved detection for return visits to the same level, so that it doesn't
    award level-clear lives multiple times in games like Hexen.
  - Tooltips now display on the left side of the screen rather than the bottom,
    so that they no longer cover the last few options.
  - Time stop effect could permanently make sounds stop playing

# 0.2.8

- Fix:
  - "max lives per boss kill" did not function correctly when set to 0/unlimited
  - boss kills were not reliably detected

# 0.2.7

- Fix:
  - Under rare circumstances, when wearing armour in the first level of the game, it was possible for invincibility to trigger on hits that would have almost, but not quite, killed you. It should now only trigger on hits that would otherwise be lethal, even in the first level.

# 0.2.6

- New:
  - Time stop behaviour can be configured to slow time by ½, ¼, or ⅛ instead of stopping time outright.
- Fix:
  - libtooltipmenu is now integrated. This fixes compatibility with other mods that have improperly copied libttm into their pk3.

# 0.2.5

- Fix:
  - Options menu now accurately reflects how "starting lives" and "lives per level" interact.
  - README tells players about the options menu.

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

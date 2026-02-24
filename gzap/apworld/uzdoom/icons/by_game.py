'''
Game-specific mappings from item names to icons.
'''

_ICON_GUESSES = {
  'Aquaria': [
    ('music',   {' form', ' song',}),
    ('armour',  {'costume'}),
    # TODO: we need a food icon for most of the things in this game, and a
    # turtle, map, or trans flag for the transturtles
  ],
  # apdoom/apheretic guesses. These are used only if you aren't playing a compatible
  # iwad; e.g. if you are playing a Doom 2 megawad, it will use native Doom 2
  # sprites and uses the guesses here only for apheretic.
  'DOOM 1993': [
    ('key',     {'keycard', 'skull key'}),
    ('book',    {'area map'}),
    ('key',     {' (e1m', ' (e2m', ' (e3m', ' (e4m'}),
  ],
  'DOOM II': [
    ('key',     {'keycard', 'skull key'}),
    ('book',    {'area map'}),
    ('key',     {' (map'}),
  ],
  'Heretic': [
    ('key',     {'green key', 'yellow key', 'blue key'}),
    ('book',    {'map scroll'}),
    ('key',     {' (e1m', ' (e2m', ' (e3m', ' (e4m', ' (e5m'}),
  ],
  # This doesn't currently work because the Timespinner apworld doesn't set a
  # worldname and just shows up as 'Generic'.
  'Timespinner': [
    ('key',     {'timespinner'}),
  ],
}

def guess_icon_for_game(game, name):
  if game not in _ICON_GUESSES:
    return False

  name = name.lower()
  for icon,substrings in _ICON_GUESSES[game]:
    for substr in substrings:
      if substr in name:
        return icon

  return False

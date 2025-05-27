'''
Small library for guessing in-game icons to use to display things from other games.

Inspired by LADX's ItemIconGuessing lib.
'''

import re

# List of icon guesses. List so that we can control the order things are processed in.
# First entry in each pair is the icon name to use, second is a set of substrings --
# if any substring is contained in the item name we will use that icon.
# TODO: support game-specific guesses.
_ICON_GUESSES = [
  ('shield',  {'shield', 'buckler', 'aegis'}),
  ('ring',    {'ring', 'bracelet'}),
  ('amulet',  {'amulet', 'charm', 'necklace', 'brooch'}),
  ('bow',     {'bow', 'crossbow'}),
  ('gun',     {'gun', 'rifle', 'pistol', 'beam', 'cannon'}),
  ('sword',   {'sword', 'blade', 'knife', 'dagger'}),
  ('armour',  {'armor', 'armour', 'coat', 'jacket', 'shirt'}),
  ('helmet',  {'helm', 'hat', 'crown', 'circlet', 'diadem'}),
  ('staff',   {'staff', 'wand', 'rod'}),
  ('bomb',    {'bomb', 'tnt', 'explosive', 'firecracker', 'grenade'}),
  ('book',    {'book', 'tome', 'codex', 'grimoire'}),
  ('potion',  {'potion', 'bottle', 'medicine', 'flask', 'drink', 'heal', 'revive'}),
  ('money',   {'rupee', 'money', 'geo_chest', 'geo_rock', 'dollars', 'coins'}),
  ('gem',     {'gem', 'jewel', 'crystal', 'sapphire', 'ruby', 'emerald', 'diamond'}),
  ('key',     {'key', 'triforce', 'questagon', 'access'}),
  ('arrow',   {'arrow', 'missile', 'ammo'}),
  ('upgrade', {'max ', 'upgrade'}),
  ('orb',     {'orb', 'ball'}),
]

# Icon shortname to actual name mapping.
# The actual images are PNGs stored in gzap/sprites/raw/
_ICON_SPRITES = {
  'amulet' : 'NecklaceOutline 8',
  'armour' : 'TorsoOutline 5',
  'arrow'  : 'ArrowOutline 6',
  'bomb'   : 'ArtifactOutline 33',
  'book'   : 'BookOutline 4',
  'bow'    : 'RangedOutline 10',
  'gem'    : 'MiscellaneousOutline 24',
  'gun'    : 'StaffOutline 7',
  'helmet' : 'HelmetOutline 19',
  'key'    : 'KeyOutline 3',
  'money'  : 'ArtifactOutline 49',
  'orb'    : 'ArtifactOutline 31',
  'potion' : 'ArtifactOutline 40',
  'ring'   : 'RingOutline 12',
  'shield' : 'ShieldOutline 8',
  'staff'  : 'StaffOutline 5',
  'sword'  : 'SwordOutline 34',
  'upgrade': 'ArtifactOutline 20',
}

_ICON_FRAMES = {
  name: index
  for index,name in enumerate(sorted(_ICON_SPRITES.keys()))
}

def build_icons():
  from shutil import copy
  for index,icon in enumerate(sorted(_ICON_SPRITES.keys())):
    assert index < 26
    src = f'assets/{_ICON_SPRITES[icon]}.png'
    dst = f'sprites/icons/ap00{chr(_ICON_FRAMES[icon] + ord('A'))}0.png'
    print(f'{_ICON_SPRITES[icon]} -> AP00{chr(_ICON_FRAMES[icon] + ord('A'))}0.png')
    copy(src, dst)

def guess_icon(game: str, name: str) -> str:
  '''
  Try to guess what icon to display in gzDoom based on the name of an item.

  Items native to gzdoom are always displayed as themselves. This guesswork is
  only for icons from other games. It consists of two parts -- a table joining
  item name regexes with simple icon names, and a table mapping simple icon
  names to GZAP four-letter sprite IDs.
  '''
  name = name.lower()
  for icon,substrings in _ICON_GUESSES:
    for substr in substrings:
      if substr in name:
        return f'ICON:AP00:{_ICON_FRAMES[icon]}'

  return ''

if __name__ == '__main__':
  build_icons()


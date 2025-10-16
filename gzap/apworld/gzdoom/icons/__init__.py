'''
Small library for guessing in-game icons to use to display things from other games.

Inspired by LADX's ItemIconGuessing lib.
'''

if __name__ != '__main__':
  from .apdoom import guess_apdoom_typename
  from .apheretic import guess_apheretic_typename
  from .by_game import guess_icon_for_game
  from .generic import guess_generic_icon

# Icon shortname to actual name mapping.
# These end up in sprites/icons/ in the AP01 sprite space
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
  'music'  : 'instrument-harp',
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
    dst = f'sprites/icons/ap01{chr(_ICON_FRAMES[icon] + ord("A"))}0.png'
    print(f'{_ICON_SPRITES[icon]} -> AP01{chr(_ICON_FRAMES[icon] + ord("A"))}0.png')
    copy(src, dst)

def icon_to_frame(icon_name):
  if not icon_name:
    return False
  return f'ICON:AP01:{_ICON_FRAMES[icon_name]}'

def guess_icon(wad, game: str, name: str) -> str:
  '''
  Try to guess what icon to display in gzDoom based on the name of an item.

  Items native to gzdoom are always displayed as themselves. This guesswork is
  only for icons from other games. It consists of two parts -- a table joining
  item name regexes with simple icon names, and a table mapping simple icon
  names to GZAP four-letter sprite IDs.
  '''
  return (
    guess_apdoom_typename(wad, game, name)
    or guess_apheretic_typename(wad, game, name)
    or icon_to_frame(guess_icon_for_game(game, name))
    or icon_to_frame(guess_generic_icon(name)))

if __name__ == '__main__':
  build_icons()


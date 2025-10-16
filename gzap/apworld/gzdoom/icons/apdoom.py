'''
Mapping from APDoom AP item names to gzDoom actor names.
'''

_APDOOM_ICONS = {
  'Shotgun':                'Shotgun',
  'Rocket launcher':        'RocketLauncher',
  'Plasma gun':             'PlasmaRifle',
  'Chainsaw':               'Chainsaw',
  'Chaingun':               'Chaingun',
  'BFG9000':                'BFG9000',
  'Super Shotgun':          'SuperShotgun',
  'Armor':                  'GreenArmor',
  'Mega Armor':             'BlueArmor',
  'Berserk':                'Berserk',
  'Invulnerability':        'InvulnerabilitySphere',
  'Partial invisibility':   'BlurSphere',
  'Supercharge':            'Soulsphere',
  'Megasphere':             'Megasphere',
  'Medikit':                'Medikit',
  'Box of bullets':         'ClipBox',
  'Box of rockets':         'RocketBox',
  'Box of shotgun shells':  'ShellBox',
  'Energy cell pack':       'CellPack',
  'Computer area map':      'Allmap',
  'Backpack':               'Backpack',
  'Bullet capacity':        'Backpack',
  'Shell capacity':         'Backpack',
  'Energy cell capacity':   'Backpack',
  'Rocket capacity':        'Backpack',
  'Blue keycard':           'BlueCard',
  'Blue skull key':         'BlueSkull',
  'Yellow keycard':         'YellowCard',
  'Yellow skull key':       'YellowSkull',
  'Red keycard':            'RedCard',
  'Red skull key':          'RedSkull',
  # FreeDoom-specific item names
  'ripsaw':                 'Chainsaw',
  'pump-action shotgun':    'Shotgun',
  'double-barrelled shotgun':'SuperShotgun',
  'minigun':                'Chaingun',
  'missile launcher':       'RocketLauncher',
  'polaric energy weapon':  'PlasmaRifle',
  'SKAG 1337':              'BFG9000',
}

_APDOOM_REGEXES = [
  (r' - Blue keycard$',     'BlueCard'),
  (r' - Yellow keycard$',   'YellowCard'),
  (r' - Red keycard$',      'RedCard'),
  (r' - Blue skull key$',   'BlueSkull'),
  (r' - Yellow skull key$', 'YellowSkull'),
  (r' - Red skull key$',    'RedSkull'),
  (r' - Computer area map$','Allmap'),
  (r' \(E.M.\)$',           'LostSoul'),
  (r' \(MAP..\)$',          'LostSoul'),
]

import re
def guess_from_regexes(name):
  for (regex, typename) in _APDOOM_REGEXES:
    if re.search(regex, name):
      return typename
  return False

def guess_apdoom_typename(wad, game, name):
  # print("guess_doom_typename", game, name, wad.is_doom(), name in _APDOOM_ICONS, guess_from_regexes(name))
  return (
    game in {'DOOM 1993', 'DOOM II'}
    and wad.is_doom()
    and _APDOOM_ICONS.get(name, guess_from_regexes(name)))

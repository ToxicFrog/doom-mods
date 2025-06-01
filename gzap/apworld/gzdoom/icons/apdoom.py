'''
Mapping from APDoom AP item names to gzDoom actor names.
'''

# TODO: Known infelicity here -- level accesses are named (e.g.)
#  "The Underhalls (MAP02)"
# and keys are named
#  "The Underhalls (MAP02) - Blue keycard"
# neither of which are picked up by this, so it ends up falling back to
# the generic guessers.
# APHeretic has the same issue.
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

def guess_apdoom_typename(wad, game, name):
  # print("guess_doom_typename", game, name, wad.is_doom(), name in _APDOOM_ICONS, guess_from_regexes(name))
  return (
    game in {'DOOM 1993', 'DOOM II'}
    and wad.is_doom()
    and _APDOOM_ICONS.get(name, False))

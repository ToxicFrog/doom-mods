'''
Mapping from APHeretic AP item names to gzDoom actor names.
'''

_APHERETIC_ICONS = {
  'Gauntlets of the Necromancer':   'Gauntlets',
  'Ethereal Crossbow':              'Crossbow',
  'Dragon Claw':                    'Blaster',
  'Phoenix Rod':                    'PhoenixRod',
  'Firemace':                       'Mace',
  'Hellstaff':                      'SkullRod',
  'Chaos Device':                   'ArtiTeleport',
  'Wings of Wrath':                 'ArtiFly',
  'Morph Ovum':                     'ArtiEgg',
  'Mystic Urn':                     'ArtiSuperHealth',
  'Quartz Flask':                   'ArtiHealth',
  'Ring of Invincibility':          'ArtiInvulnerability',
  'Shadowsphere':                   'ArtiInvisibility',
  'Timebomb of the Ancients':       'ArtiTimeBomb',
  'Tome of Power':                  'ArtiTomeOfPower',
  'Torch':                          'ArtiTorch',
  'Silver Shield':                  'SilverShield',
  'Enchanted Shield':               'Enchantedshield',
  'Crystal Geode':                  'GoldWandHefty',
  'Energy Orb':                     'BlasterHefty',
  'Greater Runes':                  'SkullRodHefty',
  'Inferno Orb':                    'PhoenixRodHefty',
  'Pile of Mace Spheres':           'MaceHefty',
  'Quiver of Ethereal Arrows':      'CrossbowHefty',
  'Map Scroll':                     'SuperMap',
  'Bag of Holding':                 'BagOfHolding',
  'Crystal Capacity':               'BagOfHolding',
  'Ethereal Arrow Capacity':        'BagOfHolding',
  'Claw Orb Capacity':              'BagOfHolding',
  'Rune Capacity':                  'BagOfHolding',
  'Flame Orb Capacity':             'BagOfHolding',
  'Mace Sphere Capacity':           'BagOfHolding',
  'Yellow key':                     'KeyYellow',
  'Green key':                      'KeyGreen',
  'Blue key':                       'KeyBlue',
}

_APHERETIC_REGEXES = [
  (r' - Blue key$',     'KeyBlue'),
  (r' - Yellow key$',   'KeyYellow'),
  (r' - Green key$',    'KeyGreen'),
  (r' - Map Scroll$',   'SuperMap'),
  (r' \(E.M.\)$',       'HereticImp'),
]

import re
def guess_from_regexes(name):
  for (regex, typename) in _APHERETIC_REGEXES:
    if re.search(regex, name):
      return typename
  return False

def guess_apheretic_typename(wad, game, name):
  # print("guess_apheretic_typename", game, name, wad.is_heretic(), name in _APHERETIC_ICONS, guess_from_regexes(name))
  return (
    game == 'Heretic'
    and wad.is_heretic()
    and _APHERETIC_ICONS.get(name, guess_from_regexes(name)))

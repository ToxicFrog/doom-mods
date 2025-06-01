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

def guess_apheretic_typename(wad, game, name):
  return (
    game == 'Heretic'
    and 'Tome of Power' in wad.items_by_name
    and _APHERETIC_ICONS.get(name, False))

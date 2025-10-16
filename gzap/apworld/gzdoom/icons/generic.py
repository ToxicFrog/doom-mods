'''
Mapping from item name substrings to generic icons for items that we don't have a specific mapping for.

This is used if we have no game-specific mapping for an item.
'''

# List of icon guesses. List so that we can control the order things are processed in.
# First entry in each pair is the icon name to use, second is a set of substrings --
# if any substring is contained in the item name we will use that icon.
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
  ('music',   {'song', 'music', 'instrument'}),
  ('bomb',    {'bomb', 'tnt', 'explosive', 'firecracker', 'grenade'}),
  ('book',    {'book', 'tome', 'codex', 'grimoire'}),
  ('potion',  {'potion', 'bottle', 'medicine', 'flask', 'drink', 'heal', 'revive'}),
  ('money',   {'rupee', 'money', 'geo_chest', 'geo_rock', 'dollars', 'coins'}),
  ('gem',     {'gem', 'jewel', 'crystal', 'sapphire', 'ruby', 'emerald', 'diamond', 'topaz'}),
  ('key',     {'key', 'triforce', 'questagon', 'access'}),
  ('arrow',   {'arrow', 'missile', 'ammo'}),
  ('upgrade', {'max ', 'upgrade'}),
  ('orb',     {'orb', 'ball'}),
  ('sword',   {'weapon'}), # Fallback for generic "progressive weapon" and similar
]

def guess_generic_icon(name):
  name = name.lower()
  for icon,substrings in _ICON_GUESSES:
    for substr in substrings:
      if substr in name:
        return icon
  return False

'''
Location/region access prerequisites.

This library contains functions for turning textual prerequisites like
'key/RedCard' or 'map/E1M1/belltower' into location access rule functions.
'''

from typing import FrozenSet

def strings_to_prereq_fn(world, wad, map, xs):
  rules = [string_to_prereq_fn(world, wad, map, x) for x in xs]
  def prereq(state):
    for rule in rules:
      if not rule(state):
        return False
    return True
  return prereq

def string_to_prereq_fn(world, wad, map, string):
  fields = string.split('/')
  if len(fields) == 3:
    type,name,qualifier = fields
  else:
    type,name = fields
    qualifier = None

  match type:
    case 'fqin':
      return fqin_prereq(world, wad, map, name)
    case 'key':
      return key_prereq(world, wad, map, name)
    case 'item':
      return item_prereq(world, wad, map, name)
    case 'map':
      return region_prereq(world, wad, map, name, qualifier)
    case 'weapon':
      return weapon_prereq(world, wad, map, name, qualifier)
    case _:
      raise RuntimeError(f'Unknown prerequisite {string}')

def fqin_prereq(world, wad, map, fqin):
  return lambda state: state.has(fqin, world.player)

def item_prereq(world, wad, map, typename):
  return fqin_prereq(world, wad, map, wad.items_by_type[typename].name())

def weapon_prereq(world, wad, map, typename, strictness):
  if strictness == 'need':
    return item_prereq(world, wad, map, typename)
  else:
    # TODO: use this for more sophisticated weapon logic
    return lambda state: True

def key_prereq(world, wad, map, typename):
  return fqin_prereq(world, wad, map, map.key_by_type(typename).fqin())

def region_prereq(world, wad, map, mapname, subregion):
  # In the above, 'map' is the map this prereq is evaluated in the context of,
  # and mapname is the name of the other map we're evaluating.
  if subregion is None:
    return wad.maps[mapname].access_rule(world)
  else:
    return wad.regions[f'{mapname}/{subregion}'].access_rule(world, wad, map)

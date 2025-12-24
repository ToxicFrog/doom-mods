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
  # print('string_to_prereq', wad.name, map.map, string)
  fields = string.split('/')

  match fields[0]:
    case 'fqin':
      return fqin_prereq(world, wad, map, *fields[1:])
    case 'key':
      return key_prereq(world, wad, map, *fields[1:])
    case 'item':
      return item_prereq(world, wad, map, *fields[1:])
    case 'map':
      return region_prereq(world, wad, map, *fields[1:])
    case 'weapon':
      return weapon_prereq(world, wad, map, *fields[1:])
    case _:
      raise RuntimeError(f'Unknown prerequisite {string}')

def fqin_prereq(world, wad, map, fqin):
  # print(f'    (has "{fqin}")')
  return lambda state: state.has(fqin, world.player)

def item_prereq(world, wad, map, typename):
  return fqin_prereq(world, wad, map, wad.items_by_type[typename].name())

def weapon_prereq(world, wad, map, typename, strictness = 'need'):
  if strictness == 'need':
    return item_prereq(world, wad, map, typename)
  else:
    # TODO: use this for more sophisticated weapon logic
    # print('    (constantly true)')
    return lambda state: True

def key_prereq(world, wad, map, typename):
  if typename == '*':
    # match any key in cluster
    prereqs = [
      fqin_prereq(world, wad, map, key.fqin())
      for key in sorted(map.keyset)
    ]
    return lambda state: sum(p(state) for p in prereqs) > 0
  else:
    return fqin_prereq(world, wad, map, map.key_by_type(typename).fqin())

def region_prereq(world, wad, map, mapname, subregion = None):
  # In the above, 'map' is the map this prereq is evaluated in the context of,
  # and mapname is the name of the other map we're evaluating.
  if subregion is None:
    # print(f'    (reachable "{mapname}")')
    return wad.maps[mapname].access_rule(world)
  else:
    # print(f'    (reachable "{mapname}/{subregion}")')
    return wad.regions[f'{mapname}/{subregion}'].access_rule(world, wad, map)

'''
Location/region access prerequisites.

This library contains functions for turning textual prerequisites like
'key/RedCard' or 'map/E1M1/belltower' into location access rule functions.

TODO: we should use the new rule builder API in AP 0.6.7 once it's released.
'''

from typing import FrozenSet

from rule_builder.rules import *

def strings_to_rule(world, wad, map, xs):
  if xs:
    return And(*[string_to_rule(world, wad, map, x) for x in xs])
  else:
    return True_()

def string_to_rule(world, wad, map, string):
  # print('string_to_prereq', wad.name, map.map, string)
  fields = string.split('/')

  match fields[0]:
    case 'fqin':  # fqin/ITEMNAME[/COUNT]
      return fqin_prereq(world, wad, map, *fields[1:])
    case 'key':  # key/TYPENAME[/COUNT]
      return key_prereq(world, wad, map, *fields[1:])
    case 'item':  # item/TYPENAME[/COUNT]
      return item_prereq(world, wad, map, *fields[1:])
    case 'map':  # map/MAP[/SUBREGION]
      return region_prereq(world, wad, map, *fields[1:])
    case 'weapon':  # weapon/TYPENAME/{want,need}
      return weapon_prereq(world, wad, map, *fields[1:])
    case 'flag':  # flag/FLAGNAME
      # Flags don't impose prerequisites but instead change other things about
      # the region or location.
      return True_()
    case _:
      raise RuntimeError(f'Unknown prerequisite {string}')

def fqin_prereq(world, wad, map, fqin, count=1):
  return Has(fqin, int(count))

def item_prereq(world, wad, map, typename, count=1):
  return fqin_prereq(world, wad, map, wad.items_by_type[typename].name())

def weapon_in_pool(world, wad, map, typename):
  global_cap = wad.weapon_capability(typename)
  local_cap = wad.weapon_capability(typename, map.map)
  return world.pool.contains_item(global_cap) or world.pool.contains_item(local_cap)

def weapon_prereq(world, wad, map, typename, strictness = 'need'):
  if strictness == 'need':
    has_global_cap = fqin_prereq(world, wad, map, wad.weapon_capability(typename))
    has_local_cap = fqin_prereq(world, wad, map, wad.weapon_capability(typename, map.map))
    return Or(has_global_cap, has_local_cap)
  elif strictness == 'want':
    if world.options.combat_logic_mode.is_enabled():
      if weapon_in_pool(world, wad, map, typename):
        return weapon_prereq(world, wad, map, typename, 'need')
      else:
        print(f'Dropping prerequisite weapon/{typename}/want in {map.map} because no such weapon exists')
        return True_()
    else:
      return True_()
  elif strictness == 'auto':
    if world.options.combat_logic_mode.is_auto():
      return weapon_prereq(world, wad, map, typename, 'need')
    else:
      return True_()
  else:
    assert False, f'Unknown strictness in weapon prereq weapon/{typename}/{strictness}'

def is_combat_logic_hint(prereq):
  return prereq.startswith('weapon/') and prereq.endswith('/want')

def weapon_from_hint(prereq):
  assert is_combat_logic_hint(prereq)
  return prereq.split('/')[1]

def key_prereq(world, wad, map, typename, count=1):
  if typename == '*':
    # match any key in cluster
    prereqs = [
      fqin_prereq(world, wad, map, key.fqin())
      for key in sorted(map.keyset)
    ]
    return Or(*prereqs) if len(prereqs) > 1 else prereqs[0]
  else:
    # TODO: if the location the key comes from is not randomized, this should
    # instead be a check that you can reach the location where the key is.
    # This does require us to somehow turn the key's type and scope back into
    # the key's originating location.
    return fqin_prereq(world, wad, map, map.key_by_type(typename).fqin(), count)

def region_prereq(world, wad, map, mapname, subregion = None):
  # In the above, 'map' is the map this prereq is evaluated in the context of,
  # and mapname is the name of the other map we're evaluating.
  if subregion is None:
    return CanReachRegion(mapname)
  else:
    return CanReachRegion(f'{mapname}/{subregion}')

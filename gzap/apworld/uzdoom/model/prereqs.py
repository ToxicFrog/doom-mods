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

# TODO: extract and unify weapon logic prereqs so that we can combine them into
# something more readable in the debugger, rather than attaching the glitch
# check and combat logic option check to each one individually.
def weapon_prereq(world, wad, map, typename, strictness = 'need'):
  has_global_cap = fqin_prereq(world, wad, map, wad.weapon_capability(typename))
  has_local_cap = fqin_prereq(world, wad, map, wad.weapon_capability(typename, map.map))

  if strictness == 'need':
    # We do this before the in_pool check because if the weapon is hard required
    # and not in the pool, we cannot guarantee the game is beatable.
    return Or(has_global_cap, has_local_cap)

  if not weapon_in_pool(world, wad, map, typename):
    print(f'Dropping prerequisite weapon/{typename}/{strictness} in {map.map} because no such weapon exists')
    return True_()

  starting_map = True_(options=[OptionFilter(world.options.starting_levels.__class__, map.map, operator="contains")])
  combat_logic_disabled = True_(options=[OptionFilter(world.options.combat_logic_mode.__class__, 0)])
  combat_logic_no_auto = True_(options=[OptionFilter(world.options.combat_logic_mode.__class__, 1, operator='le')])
  combat_logic_local_only = True_(options=[OptionFilter(world.options.combat_logic_mode.__class__, 2, operator='le')])
  if strictness == 'want':
    return Or(
      has_global_cap,
      has_local_cap,
      Has(world.glitches_item_name),
      starting_map,
      combat_logic_disabled)

  if strictness == 'auto':
    return Or(
      has_global_cap,
      has_local_cap,
      Has(world.glitches_item_name),
      starting_map,
      combat_logic_no_auto)

  if strictness == 'auto_carryover':
    return Or(
      has_global_cap,
      has_local_cap,
      Has(world.glitches_item_name),
      starting_map,
      combat_logic_local_only)

  assert False, f'Unknown strictness in weapon prereq weapon/{typename}/{strictness}'

def is_combat_logic_hint(prereq, include_auto=False):
  if not prereq.startswith('weapon/'):
    return False
  return (
    prereq.endswith('/want')
    or (include_auto and prereq.endswith('/auto')))

def weapon_from_hint(prereq):
  assert is_combat_logic_hint(prereq, True)
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

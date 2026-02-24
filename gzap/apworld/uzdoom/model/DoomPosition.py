'''
Classes representing the positions at which Checks and Locations can be found.

These are always associated with a map lump, but within that map, can be
associated with points in space, sectors, TIDs, or abstract events.
'''

from typing import NamedTuple, Optional, Set, List, FrozenSet, Collection, Union

class DoomCoordPosition(NamedTuple):
  '''
  A position associated with a specific physical point in the map.

  This is a direct copy of the `pos` field of an Actor, plus the name of the
  containing map (so we don't consider two locations with the same coordinates
  but in different maps to actually be identical).
  '''
  map: str
  x: int
  y: int
  z: int

  def as_vec3(self):
      return f'({self.x},{self.y},{self.z})'

  def has_coords(self):
    return True
  def is_secret(self):
    return False

class DoomSecretPosition(NamedTuple):
  '''
  A position associated with a secret, identified by sector index or TID.
  '''
  map: str
  secret_type: str
  secret_id: int

  def has_coords(self):
    return False
  def is_secret(self):
    return True


class DoomEventPosition(NamedTuple):
  '''
  A position associated with an event, such as 'exited the level'.
  '''
  map: str
  event_type: str

  def has_coords(self):
    return False
  def is_secret(self):
    return False


DoomPosition = Union[DoomCoordPosition,DoomSecretPosition,DoomEventPosition]

def to_position(map: str, *args) -> DoomPosition:
  if type(args[0]) is int:
    return DoomCoordPosition(map, *args)
  elif args[0] == 'secret':
    return DoomSecretPosition(map, *args[1:])
  elif args[0] == 'event':
    return DoomEventPosition(map, *args[1:])
  else:
    raise Exception(f'Error decoding position: map={map}, args={args}')

'''
Classes representing the positions at which Checks and Locations can be found.

These are always associated with a map lump, but within that map, can be
associated with points in space, sectors, TIDs, or abstract events.

All of them also define a disambiguate(level, others) method. This is called by
the WAD to resolve name collisions; see DoomCoordPosition.disambiguate for details.
'''

from typing import NamedTuple, Optional, Set, List, FrozenSet, Collection, Union
from .BoundingBox import BoundingBox

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

  def as_zscript(self):
    return f'GZAP_PhysicalLocation.Create({self.as_vec3()})'

  def disambiguate(self, level, others):
    '''
    Resolve name collisions between positions. Level is the disambiguation level;
    it starts at 0 and increases every time a disambiguation pass fails. Others
    is a list of other positions that collided with this one on the last pass.

    It should either return a string that will be appended to the location name,
    or raise.
    '''
    if level == 0:
      bb = BoundingBox()
      for pos in others:
        if hasattr(pos, 'x'):
          bb.add_point(pos)
      dir,dist = bb.position_name(self)
      if dist:
        return f'{dir} {dist}'
      else:
        return dir

    if level == 1:
      return f'{self.x},{self.y}'

    if level == 2:
      return f'{self.x},{self.y},{self.z}'

    raise RuntimeError(f'cannot further disambiguate {self}')


class DoomSecretPosition(NamedTuple):
  '''
  A position associated with a secret, identified by sector index or TID.
  '''
  map: str
  secret_type: str
  secret_id: int

  def as_zscript(self):
    if self.secret_type == 'sector':
      return f'GZAP_SecretSectorLocation.Create({self.secret_id})'
    else:
      return f'GZAP_SecretTriggerLocation.Create({self.secret_id})'

  def disambiguate(self, level, others):
    raise RuntimeError(f'cannot disambiguate secret trigger {self}')


class DoomExitPosition(NamedTuple):
  '''
  A position associated with successfully exiting the level.
  '''
  map: str
  destination: str = ""

  def as_zscript(self):
    return f'GZAP_ExitLocation.Create("{self.destination}")'

  def disambiguate(self, level, others):
    raise RuntimeError(f'cannot disambiguate exit trigger {self}')

'''
disambiguating spawn positions -- applies to both TID and coordinate spawns
there are basically two possible cases here
two spawn points in the same region -> disambiguate based on compass direction, coordinates, or TID
two spawn points at the same point, different counts -> disambiguate based on count
both of the above -> disambiguate based on both count and direction/coords/TID
'''

class DoomSpawnPosition(NamedTuple):
  '''
  A position associated with an item spawning in during gameplay, that should be
  replaced with a check.
  '''
  map: str
  count: int
  typename: str
  x: float = None
  y: float = None
  z: float = None
  r: int = 0

  def as_zscript(self):
    buf = f'GZAP_SpawnLocation.Create({self.count}, "{self.typename}")'
    if self.x is not None:
      buf += f'.WithPosition({self.x},{self.y},{self.z},{self.r})'
    return buf

  def same_position(self, other):
    return other is not self and type(self) == type(other) and (self.x,self.y) == (other.x,other.y)

  def disambiguate(self, level, others):
    # Did we collide because there are multiple spawns at this point, multiple
    # points in this region, or both?
    same_spawn = any(self.same_position(x) for x in others)
    same_region = any(self.same_position(x) for x in others)

    if same_spawn and not same_region:
      if level == 0:
        return f'#{self.count}'
      else:
        raise RuntimeError(f'cannot further disambiguate {self} from other spawns at location')

    if same_spawn:
      suffix = f' #{self.count}'
    else:
      suffix = ''

    try:
      return f'{DoomCoordPosition.disambiguate(self, level, others)}{suffix}'
    except:
      raise RuntimeError(f'cannot further disambiguate {self} from other locations in region')

class DoomSpawnTIDPosition(NamedTuple):
  '''
  As DoomSpawnPosition, but associated with a TID rather than coordinates. On
  check it will attempt to resolve the position of the first actor with that
  TID. Not safe for use on TIDs shared across multiple actors.
  '''
  map: str
  count: int
  typename: str
  tid: int = None
  r: int = 0

  def as_zscript(self):
    buf = f'GZAP_SpawnLocation.Create({self.count}, "{self.typename}")'
    buf += f'.WithTIDPosition({self.tid},{self.r})'
    return buf

  def same_position(self, other):
    return other is not self and type(self) == type(other) and self.tid == other.tid

  def disambiguate(self, level, others):
    # Did we collide because there are multiple spawns at this point, multiple
    # points in this region, or both?
    same_spawn = any(self.same_position(x) for x in others)
    same_region = any(self.same_position(x) for x in others)

    if same_spawn and not same_region:
      if level == 0:
        return f'#{self.count}'
      else:
        raise RuntimeError(f'cannot further disambiguate {self} from other spawns at location')

    if same_spawn:
      suffix = f' #{self.count}'
    else:
      suffix = ''

    if level == 0:
      return f'@{self.tid}{suffix}'
    else:
      raise RuntimeError(f'cannot further disambiguate {self} from other locations in region')

DoomPosition = Union[DoomCoordPosition,DoomSecretPosition,DoomExitPosition,DoomSpawnPosition,DoomSpawnTIDPosition]

def to_position(map: str, *args) -> DoomPosition:
  if type(args[0]) is int:
    return DoomCoordPosition(map, *args)
  elif args[0] == 'secret':
    return DoomSecretPosition(map, *args[1:])
  elif args[0] == 'exit':
    return DoomExitPosition(map, *args[1:])
  elif args[0] == 'spawn':
    return DoomSpawnPosition(map, *args[1:])
  elif args[0] == 'spawn@tid':
    return DoomSpawnTIDPosition(map, *args[1:])
  else:
    raise Exception(f'Error decoding position: map={map}, args={args}')

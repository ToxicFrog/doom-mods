from .DoomReachable import DoomReachable

class DoomRegion(DoomReachable):
  map: str
  subregion: str

  def __init__(self, map, subregion):
    self.map = map
    self.subregion = subregion
    self.debug_name = f'map/{self.map}/{self.subregion}'
    super().__init__()

  def record_tuning(self, keys):
    # Implicit dependency on the enclosing map.
    super().record_tuning(keys + [f'map/{self.map}'])

  def finalize_tuning(self, default):
    super().finalize_tuning(default + [f'map/{self.map}'])

  def name(self) -> str:
    return f'{self.map}/{self.subregion}'

"""
A simple class to query inferred level geometry and come up with names for
points within it.
"""

import math
import sys

class BoundingBox:
  xmin: int
  ymin: int
  xmax: int
  ymax: int
  width: int
  height: int

  def __init__(self):
    self.xmin = self.ymin = sys.maxsize
    self.xmax = self.ymax = -sys.maxsize

  def add_point(self, pos):
    self.xmin = min(self.xmin, pos.x)
    self.ymin = min(self.ymin, pos.y)
    self.xmax = max(self.xmax, pos.x)
    self.ymax = max(self.ymax, pos.y)
    self.width = self.xmax - self.xmin
    self.height = self.ymax - self.ymin

  def center(self):
    return ((self.xmin+self.xmax)/2, (self.ymin+self.ymax)/2)

  def basis_distance(self):
    return max(self.width, self.height)/2

  def direction(self, x, y):
    # If it's too close to center, just report it as "Center"
    if self.distance(x, y) == "Center":
      return "Center"

    # Figure out bearing from center
    (cx,cy) = self.center()
    theta = math.degrees(math.atan2(y - cy, x - cx)) % 360

    # 0° is due east and it goes counterclockwise from there.
    if theta > 337.5 or theta <= 22.5:
      return "E"
    if 22.5 < theta <= 67.5:
      return "NE"
    if 67.5 < theta <= 112.5:
      return "N"
    if 112.5 < theta <= 157.5:
      return "NW"
    if 157.5 < theta <= 202.5:
      return "W"
    if 202.5 < theta <= 247.5:
      return "SW"
    if 247.5 < theta <= 292.5:
      return "S"
    if 292.5 < theta <= 337.5:
      return "SE"
    return f"ERROR {theta}"

  def distance(self, x, y):
    d = math.dist((x,y), self.center())
    if d < self.basis_distance() * 1/10:
      return "Center"
    if d < self.basis_distance() * 4/10:
      return "Center"
    if d > self.basis_distance() * 7/3:
      return "Edge"
    return None

  def position_name(self, x, y):
    """
    Returns a (direction,distance) tuple, where both are descriptive strings
    or None.
    Direction is one of: Center, N, NW, W, SW, S, SE, E, or NE
    Distance, if present, is one of: Center, Edge
    This can be used to construct names like "BlueArmor [NW Center]" or "Soulsphere [E Edge]"
    """
    direction = self.direction(x,y)
    if direction == "Center":
      return ("Center", None)
    distance = self.distance(x,y)
    return (direction,distance)

# THE KEY LIFECYCLE
#
# When a key is detected by the scanner, it emits an AP-KEY message, containing
# information about the key's typename, what level it was found in, and what
# levels it applies to (e.g. in a Hexen-style hubcluster, a key found in one
# level typically applies to all levels in that cluster).
#
# Upon encountering an AP-KEY message, the apworld creates one of these DoomKey
# records for it, and adds it to the DoomWad indexed by FQIN (which is based on
# the key's typename and level set).
#
# When tuning a location, the unqualified key names in the tuning record are
# matched up with the corresponding key records for that map, and recorded in
# the tuned keysets for that location; the FQINs are then checked against the
# player inventory in the access rule during generation.
#
# At the end of logic+tuning processing, every location that we do not have
# a tuning record for is initialized with a fully pessimal keyset: the set of
# all keys known to apply to that map.

from typing import NamedTuple, Optional, Set, List, FrozenSet, Collection

class DoomKey(NamedTuple):
    """
    A Doom key record.

    This doesn't describe an in-game key *item*, but the concept of the key itself,
    including information about which maps it is valid for and how it is named.
    """
    typename: str   # e.g. YellowCard
    scopename: str  # Usually map name; hub/episode name for multimap keys
    cluster: int    # Cluster ID, 0 if no cluster
    maps: Set[str]  # Set of map names this key belongs to

    def __str__(self):
        if len(self.maps) > 1:
            return f"Key[{self.fqin()}] {self.maps}@C{self.cluster}"
        else:
            return f"Key[{self.fqin()}]"

    def __repr__(self):
        return str(self)

    def fqin(self):
        return f"{self.typename} ({self.scopename})"


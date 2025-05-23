#namespace GZAP;
#debug off;

class ::WinConditions play {
  int nrof_maps;
  Map<string, bool> specific_maps;

  bool Victorious(::RandoState apstate) const {
    int cleared_maps;
    int cleared_specific_maps;

    foreach (region : apstate.regions) {
      if (region.cleared) {
        ++cleared_maps;
        if (specific_maps.CheckKey(region.map)) ++cleared_specific_maps;
      }
    }

    return nrof_maps <= cleared_maps
      && specific_maps.CountUsed() <= cleared_specific_maps;
  }
}

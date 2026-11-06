def custom_options(OptionType, included_levels, secrets, spawn_filter, start_inventory_from_pool, win_map_count, **kwargs):
  included_levels.default = ["MAP01", "MAP02", "MAP03", "MAP04", "MAP05", "MAP07", "MAP08", "MAP09", "MAP10"]
  win_map_count.default = 9
  spawn_filter.special_range_names = {
    "all": 0,
    "greenhorn": 1,
    "headon": 2,
    "hedonistic": 3,
    "hardcore": 4,
    "brutalizing": 5,
    "bearzerker": 6,
  }
  start_inventory_from_pool.__doc__ += '''
  These default settings are intended to guarantee you have some sort of weapon
  for the first few rooms of MAP01, since otherwise the start is very restrictive
  and you may be expected to juke around Hellblazes without fighting them.
  '''
  start_inventory_from_pool.default = {
    'Universal Axe': 1,
    'Universal Bearzerker Axe': 1,
    'Axe (MAP01)': 1,
    'Bearzerker Axe (MAP01)': 1,
  }
  secrets.default = 2 # items and secrets

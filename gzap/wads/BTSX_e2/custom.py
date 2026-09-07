# BTSXe2 has 5 different mini-episodes, but I decided to lower the amount of starting levels to just 4
# MAPs 12 and 17 are fairly small, while 01 and 06 offer some progression even with limited weaponry
def custom_options(OptionType, starting_levels, win_map_names, **kwargs):
  starting_levels.default = ['MAP01', 'MAP06', 'MAP12', 'MAP17']
  win_map_names.default = ['MAP26', 'MAP31']

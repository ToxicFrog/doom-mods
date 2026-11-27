def custom_options(OptionType,
    starting_levels, included_levels, win_map_names, **kwargs):
  starting_levels.__doc__ += """
      Xindage's note -
  Plutonia 2 can be separated in 3 episodes each one offering 11 maps.
  You can set it as you wish for a longer or short lenght of game here is set
  to a full game playthrough on each one of cluster's starting maps.
  """
  starting_levels.default = ['MAP01', 'MAP12', 'MAP21']

  included_levels.__doc__ += """
      Xindage's note -
  If you want to play just one cluster I have set up some lists down below:
  ['MAP01', 'MAP02', 'MAP03', 'MAP04', 'MAP05', 'MAP06', 'MAP07', 'MAP08', 'MAP09', 'MAP10', 'MAP11'];
  Use win map as MAP07 and MAP11, Enemy Caught and Arch-Violence. 
  ['MAP12', 'MAP33', 'MAP13', 'MAP14', 'MAP15', 'MAP16', 'MAP17', 'MAP18', 'MAP19', 'MAP20', 'MAP31'];
  Use win map as MAP20 and MAP31, Lurking Fear and Cybernation.
  ['MAP21', 'MAP22', 'MAP23', 'MAP24', 'MAP25', 'MAP26', 'MAP27', 'MAP28', 'MAP29', 'MAP32', 'MAP30'];
  Use win map as MAP32 and MAP30, Go 4 It and The Gatewatcher.
  """

  win_map_names.__doc__ += """
      Xindage's note -
  If you're going for a full game it is best to use just the default boss maps.
  """
  win_map_names.default = ['MAP07', 'MAP11', 'MAP20', 'MAP30', 'MAP31', 'MAP32']

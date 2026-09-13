# BTSXe2 has 5 different mini-episodes, but I decided to lower the amount of starting levels to just 4
# MAPs 12 and 17 are fairly small, while 01 and 06 offer some progression even with limited weaponry
def custom_options(OptionType,
    starting_levels, start_with_keys, included_levels,
    win_map_names, win_map_count, allow_respawn, full_persistence, **kwargs):
  starting_levels.__doc__ += """
      Sayeth's note -
  BTSX E2 is separated into 5 mini-episodes each containing 3-6 levels.
  Depending on how long you want to play, I would recommend by default to keep
  the five default starting points per their mini-episode for mid-size
  playthroughs and to give you more variable access to checks, but feel free to
  reduce the amount of starting maps depending on the other people's
  multiworlds.
  """
  starting_levels.default = ['MAP01', 'MAP06', 'MAP12', 'MAP17']

  start_with_keys.__doc__ += """
      Sayeth's note -
  Highly recommend keeping this off. BTSX e2 has many large non-linear levels,
  even if playing with just the first level enabled as starting map, it contains
  a lot of items and secrets accessible without any keys. Especially so if you
  start with all mini-episode starting levels as per default, getting all the
  keys for 5 levels right from the start will be overwhelming, especially for
  multiworlds with other people.
  """

  included_levels.__doc__ += """
      Sayeth's note -
  By default I excluded all intermission maps that offer no combat, no items,
  except 'MAP16C' as it technically contains 16 small health pickups. In case
  you play with randomization of those, you may want to keep it, otherwise
  recommend excluding it.
  """

  win_map_count.__doc__ += """
      Sayeth's note -
  My recommended setting here is 20 for long playthrough, 15 for mid-sized one
  and 10 for bite-sized one.
  """

  win_map_names.__doc__ += """
      Sayeth's note -
  BTSX e2 is separated into 5 mini-episodes each containing 3-6 levels.
  My recommendation is to put either finales of each episode as Winmap - this
  means: 'MAP04', 'MAP10', 'MAP15', 'MAP22', 'MAP26' and/or the secret 'MAP31'
  which is a challenging Slaughtermap, and can be used instead for a potential
  climactic ending. By default, I put MAP26 and MAP31, but please be aware that
  MAP31 is VERY difficult, I don't recommend playing it without
  respawns/persistent mode enabled.
  """
  win_map_names.default = ['MAP26', 'MAP31']

  allow_respawn.__doc__ += """
      Sayeth's note -
  Highly recommended to turn this on if playing with MAP31 enabled.
  No problems with respawning in any of the maps that I could find.
  """

  full_persistence.__doc__ += """
      Sayeth's note -
  Highly recommended to turn this on if playing with MAP31 enabled.
  No problems with persistence in any of the maps outside of MAP02 secret, which
  requires strafejump across at the level spawn and can't be repeated if failed,
  unless you die and respawn. It's marked in logic as inaccessible to not force
  player to die to repeat this.
  """

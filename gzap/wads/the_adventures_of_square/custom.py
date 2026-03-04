from Options import Visibility

def custom_options(OptionType, full_persistence, **kwargs):
  full_persistence.default = False
  full_persistence.visibility = Visibility.none

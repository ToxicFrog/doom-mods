# TT uses ACS to give you the chainsaw and shotgun at the start of each map,
# and the chainsaw doesn't appear in any levels and thus doesn't get scanned
# at all.
def custom_options(OptionType, start_inventory, **kwargs):
  start_inventory.default = { '64Chainsaw': 1, 'Shotgun': 1 }

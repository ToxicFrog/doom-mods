import re

# TODO: this is a quick hack. Ideally we should replace it with our own subclass
# ofjsontotextparser that emits gzdoom colour codes directly.
# Unfortunately a lot of rawjsontotextparser is implemented as module scope functions
# in NetUtils rather than class members, so it might have complications.

# Mapping from terminal colour codes emitted by rawjsontotextparser, to
# gzdoom internal colour names.
_TEXTCOLOR_ESCAPE = "\x1C"
_COLOURTABLE = {
  "0": "-", # reset
  # 1bpp ANSI palette
  "30": "[BLACK]",
  "31": "[RED]",  # also salmon
  "32": "[GREEN]",
  "33": "[YELLOW]",
  "34": "[BLUE]",  # also slateblue
  "35": "[PURPLE]",  # also magenta, plum
  "36": "[CYAN]",
  "37": "[WHITE]",
  # AIXTerm palette -- these should be brighter than the ANSI ones but we just
  # map them to the same colours.
  "90": "[BLACK]",
  "91": "[RED]",  # also salmon
  "92": "[GREEN]",
  "93": "[YELLOW]",
  "94": "[BLUE]",  # also slateblue
  "95": "[PURPLE]",  # also magenta, plum
  "96": "[CYAN]",
  "97": "[WHITE]",
}

def _gzd_escape(colour):
  return f"{_TEXTCOLOR_ESCAPE}{colour}"

def _convert_sgr(sgr: re.Match) -> str:
  sgr = sgr.group(1)
  if sgr in _COLOURTABLE:
    return _gzd_escape(_COLOURTABLE[sgr])
  else:
    return ""

def _8bpp_to_3bpp(index):
  index = index - 16
  blue = (index % 6) // 3
  green = ((index // 6) % 6) // 3
  red = ((index // 36) % 6) // 3
  sgr = "3%d" % (red + 2*green + 4*blue)
  return _gzd_escape(_COLOURTABLE[sgr])

def _convert_sgr_8bpp(sgr: re.Match) -> str:
  index = int(sgr.group(1))
  # 1bpp range
  if index < 16:
    sgr = "3%d" % (index % 8)
    return _gzd_escape(_COLOURTABLE[sgr])

  # greyscale range
  if index >= 232:
    index -= 232
    if index < 6:
      return _gzd_escape("[BLACK]")
    elif index < 12:
      return _gzd_escape("[DARKGRAY]")
    elif index < 18:
      return _gzd_escape("[GRAY]")
    else:
      return _gzd_escape("[WHITE]")

  return _8bpp_to_3bpp(index)

def ansi_to_gzdoom(msg: str) -> str:
  """Convert ANSI colour escapes in a string into gzDoom colour escapes."""
  return re.sub(
      "\x1B\\[38[:;]5[:;]([0-9]+)m", _convert_sgr_8bpp,
      re.sub("\x1B\\[([0-9]+)m", _convert_sgr, msg))

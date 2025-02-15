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
  "30": "[BLACK]",
  "31": "[RED]",  # also salmon
  "32": "[GREEN]",
  "33": "[YELLOW]",
  "34": "[BLUE]",  # also slateblue
  "35": "[PURPLE]",  # also magenta, plum
  "36": "[CYAN]",
  "37": "[WHITE]",
}

def _convert_sgr(sgr: re.Match) -> str:
  sgr = sgr.group(1)
  if sgr in _COLOURTABLE:
    return f"{_TEXTCOLOR_ESCAPE}{_COLOURTABLE[sgr]}"
  else:
    return ""

def ansi_to_gzdoom(msg: str) -> str:
  """Convert ANSI colour escapes in a string into gzDoom colour escapes."""
  return re.sub("\x1B\\[([0-9]+)m", _convert_sgr, msg)

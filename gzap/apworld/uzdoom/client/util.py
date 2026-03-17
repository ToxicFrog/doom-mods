import re

from NetUtils import JSONtoTextParser, JSONMessagePart

class JSONToZDoomTextParser(JSONtoTextParser):
  def _handle_item_name(self, node):
    print(node)
    return super()._handle_item_name(node)

  def _handle_color(self, node: JSONMessagePart):
    codes = node['color'].split(';')
    buffer = ''.join(color_code(code) for code in codes if code in _COLOURTABLE)
    return buffer + self._handle_text(node) + color_code('reset')

def color_code(code):
  return f'{_TEXTCOLOR_ESCAPE}{_COLOURTABLE[code]}'

_TEXTCOLOR_ESCAPE = '\x1C'
_COLOURTABLE = {
  # Specials
  # No support for bold/underline
  'reset': '-',
  # 3-bit (1bpp) colours
  'black': '[BLACK]',
  'red': '[RED]',
  'green': '[GREEN]',
  'yellow': '[TAN]',  # A somewhat more pastel colour that more closes matches the AP UI
  'blue': '[BLUE]',
  'magenta': '[PURPLE]',  # ZD purple is a lot closer to magenta in practice
  'cyan': '[CYAN]',
  'white': '[WHITE]',
  # Extra colours
  'plum': '[VIOLET]',  # Used for progression items; defined in TEXTCOLO
  'slateblue': '[BLUE]',  # Used for useful items
  'salmon': '[RED]',  # Used for traps
  # No support for background colours
}

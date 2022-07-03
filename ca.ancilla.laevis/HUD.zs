#namespace TFLV;

const HUD_HEIGHT = 512; // width is always 3x height
const HUD_WXP_X = 492;
const HUD_WXP_W = 916;
const HUD_PXP_X = 491;
const HUD_PXP_W = 304;

// Northwest gravity
const HUD_TOPTEXT_X = 135;
const HUD_TOPTEXT_Y = 117;
// Southeast gravity
const HUD_BOTTEXT_X = 400;
const HUD_BOTTEXT_Y = 392;
// Southwest gravity
const HUD_INFOTEXT_X = 498;
const HUD_INFOTEXT_Y = 271;

enum ::HUD::Gravity {
  HUD_GRAV_NW,
  HUD_GRAV_SW,
  HUD_GRAV_NE,
  HUD_GRAV_SE
}

class ::HUD : Object ui {
  double hudscale;
  uint hudx, hudy;
  uint hudw, hudh;

  void Draw(::CurrentStats stats) {
    Calibrate();
    DrawXPGauge(stats);
  }

  void Calibrate() {
    double x, y, size;
    [x, y, size] = ::Settings.hud_params();
    uint h = (size <= 1) ? floor(HUD_HEIGHT * size) : size;
    self.hudh = h;
    self.hudw = 3*h;
    self.hudx = realposition(screen.GetWidth(), self.hudw, x);
    self.hudy = realposition(screen.GetHeight(), self.hudh, y);
    self.hudscale = double(h)/HUD_HEIGHT;
  }

  static uint realposition(double field_size, double obj_size, double setting) {
    if (setting >= 0.0 && setting <= 1.0) {
      return (field_size - obj_size)*setting;
    } else if (setting < 0) {
      return field_size + setting - obj_size;
    } else {
      return setting;
    }
  }

  static TextureID tex(string name) {
    return TexMan.CheckForTexture(name, TexMan.TYPE_ANY);
  }

  // Coordinates are in HUD texture coordinate space, relative to the top left
  // corner of the HUD.
  void Text(string text, uint colour, uint x, uint y, ::HUD::Gravity grav) {
    // Convert to screen coordinate space.
    x = hudx + x*hudscale; y = hudy + y*hudscale;

    // Adjust for gravity based on the as-rendered size of the text.
    switch (grav) {
      case HUD_GRAV_NW:
        // No changes needed.
        break;
      case HUD_GRAV_SE:
        x = x - NewSmallFont.StringWidth(text);
        y = y - NewSmallFont.GetHeight();
        break;
      case HUD_GRAV_NE:
        x = x - NewSmallFont.StringWidth(text);
        break;
      case HUD_GRAV_SW:
        y = y - NewSmallFont.GetHeight();
        break;
    }

    screen.DrawText(NewSmallFont, colour, x, y, text);
  }

  void DrawXPGauge(::CurrentStats stats) {

    Screen.DrawTexture(tex("LHUDA2"), false, hudx, hudy,
        // DTA_Color, 0xFFFF0000, // TODO add a cvar for colour picking
        DTA_DestWidth, hudw, DTA_DestHeight, hudh);

    Screen.DrawTexture(tex("LHDWA2"), false, hudx, hudy,
        DTA_DestWidth, hudw, DTA_DestHeight, hudh,
        DTA_ClipRight,
        uint(hudx + hudscale*(HUD_WXP_X + HUD_WXP_W * (double(stats.wxp)/(stats.wmax)))));

    Screen.DrawTexture(tex("LHDPA2"), false, hudx, hudy,
        DTA_DestWidth, hudw, DTA_DestHeight, hudh,
        DTA_ClipRight,
        uint(hudx + hudscale*(HUD_PXP_X + HUD_PXP_W * (double(stats.pxp)/(stats.pmax)))));

    Text("P:"..stats.plvl, Font.CR_GREEN, HUD_TOPTEXT_X, HUD_TOPTEXT_Y, HUD_GRAV_NW);
    Text("W:"..stats.wlvl, Font.CR_BLUE, HUD_BOTTEXT_X, HUD_BOTTEXT_Y, HUD_GRAV_SE);

    Text("XP: "..stats.wxp.."/"..stats.wmax,
        Font.CR_ORANGE, HUD_INFOTEXT_X, HUD_INFOTEXT_Y, HUD_GRAV_SW);
    Text(stats.effect .. (stats.effect == "" ? "" : " ") .. stats.wname,
        // HACK HACK HACK, we adjust y in HUD coordinate space so that it ends up
        // in the right place (directly above the XP: line) when it gets rendered.
        Font.CR_ORANGE, HUD_INFOTEXT_X, HUD_INFOTEXT_Y - NewSmallFont.GetHeight()/hudscale, HUD_GRAV_SW);
  }
}


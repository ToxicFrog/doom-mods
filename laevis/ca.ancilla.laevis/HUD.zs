#namespace TFLV;

// All values here are in texture coordinate space.
const HUD_HEIGHT = 512;
const HUD_WIDTH = 3*HUD_HEIGHT;
// Starting X coordinate and total width of XP bars.
const HUD_WXP_X = 492;
const HUD_WXP_W = 916;
const HUD_PXP_X = 491;
const HUD_PXP_W = 304;
// Text positioning.
// Northwest gravity
const HUD_TOPTEXT_X = 135;
const HUD_TOPTEXT_Y = 117;
// Southeast gravity
const HUD_BOTTEXT_X = 400;
const HUD_BOTTEXT_Y = 392;
// Southwest gravity
const HUD_INFOTEXT_X = 508;
const HUD_INFOTEXT_Y = 271;

enum ::HUD::Gravity {
  HUD_GRAV_NW = 0,
  HUD_GRAV_NE = 1,
  HUD_GRAV_SW = 2,
  HUD_GRAV_SE = 3
}

enum ::HUD::Mirror {
  HUD_MIRROR_H = 1,
  HUD_MIRROR_V = 2
}

class ::HUD : Object ui {
  double hudscale;
  uint hudx, hudy;
  uint hudw, hudh;
  uint mirror;

  void Draw(::CurrentStats stats) {
    Calibrate();
    DrawHUD(stats);
  }

  void Calibrate() {
    double x, y, size;
    [x, y, size, self.mirror] = ::Settings.hud_params();
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
    // Apply mirroring settings.
    if (mirror & HUD_MIRROR_H) x = HUD_WIDTH - x;
    if (mirror & HUD_MIRROR_V) y = HUD_HEIGHT - y + 10; // A bit of padding
    grav ^= mirror;

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

    screen.DrawText(NewSmallFont, Font.CR_WHITE, x, y, text, DTA_Color, colour);
  }

  void DrawProgressBar(TextureID texture, uint colour, double progress, uint tx, uint tw) {
    uint clip_at;
    if (mirror & HUD_MIRROR_H) {
      clip_at = hudx + hudscale*(HUD_WIDTH - tx - tw*progress);
      // clip_at = hudx + hudscale*tw*progress; //hudscale*(3*HUD_WIDTH - tx - tw);;
    } else {
      clip_at = hudx + hudscale*(tx + tw*progress);
    }
    Screen.DrawTexture(
        texture, false, hudx, hudy,
        DTA_DestWidth, hudw, DTA_DestHeight, hudh,
        DTA_Color, colour,
        (mirror & HUD_MIRROR_H) ? DTA_ClipLeft : DTA_ClipRight,
        clip_at);
  }

  // We want the spike for each colour channel to sweep from 0 to 17, hold for 34,
  // then back down to 0, hold for 34, etc.
  // This is equivalent to sweeping from 0 to 51 and then back to 0, continuously,
  // but then subtracting 17 and clipping it at y=[0,17]
  // To get a triangle wave of wavelength 102 and amplitude 51, we need a sawtooth
  // wave of wavelength 102, which is just y = x % 102
  int sawtooth(int x) {
    return x % 102;
  }
  int triangle(int x) {
    return abs(sawtooth(x) - 51);
  }
  int clamped_triangle(int x) {
    return clamp(triangle(x) - 17, 0, 17);
  }

  uint GetShinyColour(int offset) {
    // Simple RGB cycle. Ramps up R to max, then G to max, then R to 0, then B
    // to max, etc. Ramps are in increments of 15.
    // To do this we generate a triangle wave with a wavelength of (255/15*6)
    // from the tic counter, centered at 0 for red, 34 for green, and 68 for blue.
    int tick = gametic % (255/15*6) - 255/15*3;
    uint r = 15 * clamped_triangle(offset + gametic);
    uint g = 15 * clamped_triangle(offset + gametic - 34);
    uint b = 15 * clamped_triangle(offset + gametic - 68);
    // ARGB8 format
    return 0xFF000000 | r<<16 | g<<8 | b;
  }

  bool LevelUp(::CurrentStats stats) {
    return stats.wxp >= stats.wmax || stats.pxp >= stats.pmax;
  }

  void DrawHUD(::CurrentStats stats) {
    uint frame_rgb, weapon_rgb, player_rgb;
    [frame_rgb, weapon_rgb, player_rgb] = ::Settings.hud_colours();
    uint face = 2;
    if (mirror & HUD_MIRROR_V) face = 4;
    if (mirror & HUD_MIRROR_H) face = 10 - face;

    Screen.DrawTexture(tex("LHUDA"..face), false, hudx, hudy,
        DTA_Color, LevelUp(stats) ? GetShinyColour(0) : frame_rgb,
        DTA_DestWidth, hudw, DTA_DestHeight, hudh);

    DrawProgressBar(
        tex("LHDWA"..face), LevelUp(stats) ? GetShinyColour(34) : weapon_rgb,
        double(stats.wxp)/(stats.wmax), HUD_WXP_X, HUD_WXP_W);
    DrawProgressBar(
        tex("LHDPA"..face), LevelUp(stats) ? GetShinyColour(68) : player_rgb,
        double(stats.pxp)/(stats.pmax), HUD_PXP_X, HUD_PXP_W);

    Text("P:"..stats.plvl, player_rgb, HUD_TOPTEXT_X, HUD_TOPTEXT_Y, HUD_GRAV_NW);
    Text("W:"..stats.wlvl, weapon_rgb, HUD_BOTTEXT_X, HUD_BOTTEXT_Y, HUD_GRAV_SE);

    Text("XP: "..stats.wxp.."/"..stats.wmax,
        weapon_rgb, HUD_INFOTEXT_X, HUD_INFOTEXT_Y, HUD_GRAV_SW);
    Text(stats.effect .. (stats.effect == "" ? "" : " ") .. stats.wname,
        // HACK HACK HACK, we adjust y in HUD coordinate space so that it ends up
        // in the right place (directly above the XP: line) when it gets rendered.
        weapon_rgb, HUD_INFOTEXT_X, HUD_INFOTEXT_Y - NewSmallFont.GetHeight()/hudscale, HUD_GRAV_SW);
  }
}


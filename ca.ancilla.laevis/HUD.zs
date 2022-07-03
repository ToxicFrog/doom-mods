#namespace TFLV;

class ::HUD : Object ui {
  static void Draw(::CurrentStats stats) {
    DrawXPGauge(stats);
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

  static void DrawXPGauge(::CurrentStats stats) {
    let w = screen.GetWidth();
    let h = screen.GetHeight();

    double hudx, hudy, hudw;
    [hudx, hudy, hudw] = ::Settings.hud_params();
    if (hudw < 1) hudw = hudw*80;

    // Position based on center point of rings
    hudx = realposition(w, hudw, hudx) + hudw/2;
    hudy = realposition(h, hudw, hudy) + hudw/2;

    Ring(hudx, hudy, hudw/2-6, 4, (double(stats.pxp)/stats.pmax), "00 FF 80");
    Ring(hudx, hudy, hudw/2, 8, (double(stats.wxp)/stats.wmax), "00 80 FF");

    screen.DrawText(NewSmallFont, Font.CR_GREEN, hudx-16, hudy-16, "P:"..stats.plvl);
    screen.DrawText(NewSmallFont, Font.CR_LIGHTBLUE, hudx-16, hudy, "W:"..stats.wlvl);
    // screen.DrawText(NewSmallFont, Font.CR_GREEN, 520, 480-48, ""..stats.plvl, DTA_VirtualWidth, 640, DTA_VirtualHeight, 480);
    // screen.DrawText(NewSmallFont, Font.CR_LIGHTBLUE, 520, 480-32, ""..stats.wlvl, DTA_VirtualWidth, 640, DTA_VirtualHeight, 480);
    // TODO: different colour depending on rarity, maybe tweak positioning
    screen.DrawText(NewSmallFont, Font.CR_ORANGE, hudx-44, hudy+28, stats.effect);
  }

  // Draw a coloured ring centered at (x,y) of radius r and thickness t.
  // len is between 0.0 and 1.0 and denotes how much of the ring to actually draw.
  // TODO: This is very expensive; with 20 segments/ring the performance hit is
  // acceptable but ideally we'd prerender all of this to a sprite sheet and
  // use DrawTexture() to actually put it on screen, which would also let us
  // make it fancier.
  const SEGMENTSIZE = 360/20;
  static void Ring(uint x, uint y, uint r, uint t, double len, string colour) {
    // Rotate by -90 degrees since gzdoom angle 0 points right
    let ox = x + r * cos(-90);
    let oy = y + r * sin(-90);
    // console.printf("Draw ring at (%d,%d) radius %d completion %f", x, y, r, len);
    for (double theta = SEGMENTSIZE - 90; theta <= len*360 - 90; theta += SEGMENTSIZE) {
      let nx = x + r * cos(theta);
      let ny = y + r * sin(theta);
      // console.printf("Draw ring segment (%d,%d)->(%d,%d), theta=%f, limit=%f", ox, oy, nx, ny, theta, len*2);
      screen.DrawThickLine(ox, oy, nx, ny, t, colour, 255);
      ox = nx;
      oy = ny;
    }
  }
}


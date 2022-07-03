#namespace TFLV;

class ::HUD : Object ui {
  static void Draw(::CurrentStats stats) {
    DrawXPGauge(stats);
  }

  static void DrawXPGauge(::CurrentStats stats) {
    let w = screen.GetWidth();
    let h = screen.GetHeight();

    // Ring(w/8 * 6, h - 48, 31, 2, 1.0, "00 00 00");
    Ring(w/8 * 6, h - 48, 34, 4, (double(stats.pxp)/stats.pmax), "00 FF 80");
    Ring(w/8 * 6, h - 48, 40, 8, (double(stats.wxp)/stats.wmax), "00 80 FF");
    // Ring(w/8 * 6, h - 48, 45, 2, 1.0, "00 00 00");
    screen.DrawText(NewSmallFont, Font.CR_GREEN, w/8*6-16, h-64, "P:"..stats.plvl);
    screen.DrawText(NewSmallFont, Font.CR_LIGHTBLUE, w/8*6-16, h-48, "W:"..stats.wlvl);
    // screen.DrawText(NewSmallFont, Font.CR_GREEN, 520, 480-48, ""..stats.plvl, DTA_VirtualWidth, 640, DTA_VirtualHeight, 480);
    // screen.DrawText(NewSmallFont, Font.CR_LIGHTBLUE, 520, 480-32, ""..stats.wlvl, DTA_VirtualWidth, 640, DTA_VirtualHeight, 480);
    // TODO: different colour depending on rarity, maybe tweak positioning
    screen.DrawText(NewSmallFont, Font.CR_ORANGE, w/8*6-44, h-20, stats.effect);
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


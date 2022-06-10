// Event handler for Laevis.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.

class TFLV_EventHandler : StaticEventHandler
{
  bool legendoomInstalled;

  override void OnRegister() {
    // If we just do cls = "LDPistol" it will get checked at compile time; we
    // need to defer this to runtime so that everything has a chance to load.
    string ldpistol = "LDPistol";
    class<Actor> cls = ldpistol;
    if (cls) {
      console.printf("Legendoom is enabled, enabling LD compatibility for Laevis.");
      legendoomInstalled = true;
    } else {
      console.printf("Couldn't find Legendoom, LD-specific features in Laevis disabled.");
      legendoomInstalled = false;
    }
  }

  TFLV_PerPlayerStats GetStatsFor(PlayerPawn pawn) const {
    return TFLV_PerPlayerStats(pawn.FindInventory("TFLV_PerPlayerStats"));
  }

  override void PlayerSpawned(PlayerEvent evt) {
    PlayerPawn pawn = players[evt.playerNumber].mo;
    if (pawn) {
      pawn.GiveInventoryType("TFLV_PerPlayerStats");
      if (legendoomInstalled) {
        GetStatsFor(pawn).legendoomInstalled = true;
      }
    }
  }

  ui void DrawXPGauge(TFLV_CurrentStats stats) {
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
  ui void Ring(uint x, uint y, uint r, uint t, double len, string colour) {
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

  override void RenderOverlay(RenderEvent evt) {
    PlayerPawn pawn = players[consoleplayer].mo;
    if (!pawn || !players[consoleplayer].ReadyWeapon) {
      return;
    }
    // TODO: only draw when cvar screenblocks == 11

    TFLV_CurrentStats stats;
    GetStatsFor(pawn).GetCurrentStats(stats);
    DrawXPGauge(stats);
  }

  void ShowInfo(PlayerPawn pawn) {
    TFLV_CurrentStats stats;
    GetStatsFor(pawn).GetCurrentStats(stats);
    console.printf("Player:\n    Level %d (%d/%d XP)\n    Damage dealt: %d%%\n    Damage taken: %d%%",
      stats.plvl, stats.pxp, stats.pmax, stats.pdmg * 100, stats.pdef * 100);
    console.printf("%s:\n    Level %d (%d/%d XP)\n    Damage dealt: %d%% (%d%% total)",
      stats.wname, stats.wlvl, stats.wxp, stats.wmax, stats.wdmg * 100, stats.pdmg * stats.wdmg * 100);
    TFLV_WeaponInfo info = GetStatsFor(pawn).GetInfoForCurrentWeapon();
    for (uint i = 0; i < info.effects.size(); ++i) {
      console.printf("%s%s (%s)",
        "    ", // TODO print marker next to selected effect
        TFLV_Util.GetEffectTitle(info.effects[i]),
        TFLV_Util.GetEffectDesc(info.effects[i]));
    }
  }

  void CycleLDPower(PlayerPawn pawn) {
    let cycler = TFLV_LegendoomEffectCycler(pawn.GiveInventoryType("TFLV_LegendoomEffectCycler"));
    if (cycler) {
      cycler.info = GetStatsFor(pawn).GetInfoForCurrentWeapon();
      cycler.prefix = cycler.info.weapon.GetClassName();
      cycler.SetStateLabel("CycleEffect");
    }
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.player != consoleplayer) {
      return;
    } else if (evt.name == "laevis_show_info") {
      ShowInfo(players[evt.player].mo);
    } else if (evt.name == "laevis_cycle_ld_power") {
      if (legendoomInstalled) {
        CycleLDPower(players[evt.player].mo);
      } else {
        console.printf("This feature only works if you also have Legendoom installed.");
      }
    }
  }
}


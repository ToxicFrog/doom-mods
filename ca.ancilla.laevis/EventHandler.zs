// Event handler for Laevis.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.

class TFLV_EventHandler : StaticEventHandler {
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

  override void PlayerSpawned(PlayerEvent evt) {
    PlayerPawn pawn = players[evt.playerNumber].mo;
    if (pawn) {
      let stats = TFLV_PerPlayerStats.GetStatsFor(pawn);
      if (!stats) stats = TFLV_PerPlayerStats(pawn.GiveInventoryType("TFLV_PerPlayerStats"));
      stats.legendoomInstalled = legendoomInstalled;
      stats.SetStateLabel("Spawn");
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
    if (TFLV_Settings.screenblocks() != 11) {
      return;
    }

    TFLV_CurrentStats stats;
    if (TFLV_PerPlayerStats.GetStatsFor(pawn).GetCurrentStats(stats))
      DrawXPGauge(stats);
  }

  void ShowInfo(PlayerPawn pawn) {
    Menu.SetMenu("LaevisStatusDisplay");
    return;
  }

  void ShowInfoConsole(PlayerPawn pawn) {
    TFLV_CurrentStats stats;
    if (!TFLV_PerPlayerStats.GetStatsFor(pawn).GetCurrentStats(stats)) return;
    console.printf("Player:\n    Level %d (%d/%d XP)",
      stats.plvl, stats.pxp, stats.pmax);
    stats.pupgrades.DumpToConsole("    ");
    console.printf("%s:\n    Level %d (%d/%d XP)",
      stats.wname, stats.wlvl, stats.wxp, stats.wmax);
    stats.wupgrades.DumpToConsole("    ");
    TFLV_WeaponInfo info = TFLV_PerPlayerStats.GetStatsFor(pawn).GetInfoForCurrentWeapon();
    console.printf("    effectSlots: %d\n    maxRarity: %d\n    canReplace: %d",
      info.effectSlots, info.maxRarity, info.canReplaceEffects);
    for (uint i = 0; i < info.effects.size(); ++i) {
      console.printf("    %s (%s)",
        TFLV_Util.GetEffectTitle(info.effects[i]),
        TFLV_Util.GetEffectDesc(info.effects[i]));
    }
  }

  void CycleLDEffect(PlayerPawn pawn) {
    TFLV_PerPlayerStats.GetStatsFor(pawn).GetInfoForCurrentWeapon().CycleEffect();
  }

  void ChooseEffectDiscard(PlayerPawn pawn, int index) {
    let stats = TFLV_PerPlayerStats.GetStatsFor(pawn);
    let giver = stats.currentEffectGiver;
    if (!giver) {
      console.printf("error: laevis_choose_effect_discard without active level up menu");
      return;
    }
    giver.DiscardEffect(index);
  }

  void SelectLDEffect(PlayerPawn pawn, int index) {
    TFLV_PerPlayerStats.GetStatsFor(pawn).GetInfoForCurrentWeapon().SelectEffect(index);
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.player != consoleplayer) {
      return;
    } else if (evt.name == "laevis_show_info") {
      ShowInfo(players[evt.player].mo);
    } else if (evt.name == "laevis_show_info_console") {
      ShowInfoConsole(players[evt.player].mo);
    } else if (evt.name == "laevis_cycle_ld_effect") {
      if (legendoomInstalled) {
        CycleLDEffect(players[evt.player].mo);
      } else {
        console.printf("This feature only works if you also have Legendoom installed.");
      }
    } else if (evt.name == "laevis_select_effect") {
      SelectLDEffect(players[evt.player].mo, evt.args[0]);
    } else if (evt.name == "laevis_choose_effect_discard") {
      ChooseEffectDiscard(players[evt.player].mo, evt.args[0]);
    }
  }
}


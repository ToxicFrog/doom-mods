// Event handler for Laevis.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.

class TFLV_EventHandler : StaticEventHandler
{
  bool legendoom_installed;

  override void OnRegister() {
    // If we just do cls = "LDPistol" it will get checked at compile time; we
    // need to defer this to runtime so that everything has a chance to load.
    string ldpistol = "LDPistol";
    class<Actor> cls = ldpistol;
    if (cls) {
      console.printf("Legendoom is enabled, enabling LD compatibility for Laevis.");
      legendoom_installed = true;
    } else {
      console.printf("Couldn't find Legendoom, LD-specific features in Laevis disabled.");
      legendoom_installed = false;
    }
  }

  TFLV_PerPlayerStats GetStatsFor(PlayerPawn pawn) const {
    return TFLV_PerPlayerStats(pawn.FindInventory("TFLV_PerPlayerStats"));
  }

  override void PlayerSpawned(PlayerEvent evt) {
    PlayerPawn pawn = players[evt.playerNumber].mo;
    if (pawn) {
      pawn.GiveInventoryType("TFLV_PerPlayerStats");
    }
  }

  ui void DrawXPBar(TFLV_CurrentStats stats) {
    let w = screen.GetWidth();
    let h = screen.GetHeight();

    // Outer dimensions of XP display, including 3px frame border on all sides.
    let framew = w/4;
    let frameh = 21;
    let framex = w/2 - framew/2;
    let framey = h - frameh;

    // Positioning for the player XP gauge.
    let pbarx = framex + 3;
    let pbary = framey + 3;
    let pbarw = (framew - 6) * (double(stats.pxp)/stats.pmax);
    let pbarh = 4;

    // Positioning for the weapon XP gauge.
    let wbarx = pbarx;
    let wbary = pbary + pbarh + 3;
    let wbarw = (framew - 6) * (double(stats.wxp)/stats.wmax);
    let wbarh = 8;

    // Draw the frames.
    // console.printf("screen (%d,%d)", w, h);
    // console.printf("uframe (%d,%d) + (%d,%d)", framex, framey, framew, pbarh + 6);
    // console.printf("lframe (%d,%d) + (%d,%d)", framex, framey + pbarh + 3, framew, wbarh + 6);
    screen.DrawFrame(framex+3, framey + 3, framew - 6, pbarh);
    screen.DrawFrame(framex+3, framey + pbarh + 6, framew - 6, wbarh);

    // Draw the gauges.
    screen.Dim("00 FF 00", 0.5, pbarx, pbary, pbarw, pbarh);
    screen.Dim("00 FF FF", 0.5, wbarx, wbary, wbarw, wbarh);

    // TODO: display textual player/weapon levels, and, once Legendoom compatibility
    // is implemented, the selected weapon ability.
  }

  override void RenderOverlay(RenderEvent evt) {
    PlayerPawn pawn = players[consoleplayer].mo;
    if (!pawn || !players[consoleplayer].ReadyWeapon) {
      return;
    }
    // TODO: only draw when cvar screenblocks == 11

    TFLV_CurrentStats stats;
    GetStatsFor(pawn).GetCurrentStats(stats);
    DrawXPBar(stats);
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.player != consoleplayer) {
      return;
    } else if (evt.name == "laevis_show_info") {
      TFLV_CurrentStats stats;
      GetStatsFor(players[evt.player].mo).GetCurrentStats(stats);
      console.printf("Player:\n    Level %d (%d/%d XP)\n    Damage bonus: %d%%\n    Armour bonus: %d%%",
        stats.plvl, stats.pxp, stats.pmax, stats.pdmg * 100, stats.pdef * 100);
      console.printf("%s:\n    Level %d (%d/%d XP)\n    Damage bonus: %d%% (%d%% total)",
        stats.wname, stats.wlvl, stats.wxp, stats.wmax, stats.wdmg * 100, stats.pdmg * stats.wdmg * 100);
    } else if (evt.name == "laevis_cycle_ld_power") {
      if (legendoom_installed) {
        console.printf("Legendoom is installed, but this feature isn't implemented yet.");
      } else {
        console.printf("This feature only works if you also have Legendoom installed.");
      }
    }
  }
}


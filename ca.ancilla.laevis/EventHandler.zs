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

  override void RenderOverlay(RenderEvent evt) {
    PlayerPawn pawn = players[consoleplayer].mo;
    if (!pawn || !players[consoleplayer].ReadyWeapon) {
      return;
    }
    // TODO: only draw when cvar screenblocks == 11

    let w = screen.GetWidth();
    let h = screen.GetHeight();
    let xpbarwidth = w/4;
    let xpbarheight = 16;

    TFLV_CurrentStats stats;
    GetStatsFor(pawn).GetCurrentStats(stats);

    // console.printf("%d %d %d %d", pxp, pmax, wxp, wmax);
    let pxpwidth = (xpbarwidth - 4) * (double(stats.pxp)/stats.pmax);
    let wxpwidth = (xpbarwidth - 4) * (double(stats.wxp)/stats.wmax);
    // console.printf("%d %d", pxpwidth, wxpwidth);
    let xpbarx = w/2 - xpbarwidth/2 + 2;

    // TODO: make this more compact and circular, and put it next to the ammo display
    // TODO: make the position configurable with cvars
    screen.ClearClipRect();
    screen.Dim("60 60 60", 0.5, w/2 - xpbarwidth/2, h-16, xpbarwidth, xpbarheight);
    screen.DrawThickLine(xpbarx, h-4, xpbarx + wxpwidth, h-4, 6, "00 80 FF", 128);
    screen.DrawThickLine(xpbarx, h-12, xpbarx + pxpwidth, h-12, 6, "00 00 FF", 128);

    // TODO: display textual player/weapon levels, and, once Legendoom compatibility
    // is implemented, the selected weapon ability.
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


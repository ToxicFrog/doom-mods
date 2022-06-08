// Event handler for Laevis.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.

class TFLV_EventHandler : StaticEventHandler
{
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

    let stats = GetStatsFor(pawn);
    uint pxp, pmax, wxp, wmax;
    [pxp, pmax, wxp, wmax] = stats.XPBarInfo();
    // console.printf("%d %d %d %d", pxp, pmax, wxp, wmax);
    let pxpwidth = (xpbarwidth - 4) * (double(pxp)/pmax);
    let wxpwidth = (xpbarwidth - 4) * (double(wxp)/wmax);
    // console.printf("%d %d", pxpwidth, wxpwidth);
    let xpbarx = w/2 - xpbarwidth/2 + 2;

    screen.ClearClipRect();
    screen.Dim("60 60 60", 0.5, w/2 - xpbarwidth/2, h-16, xpbarwidth, xpbarheight);
    screen.DrawThickLine(xpbarx, h-4, xpbarx + wxpwidth, h-4, 6, "00 80 FF", 128);
    screen.DrawThickLine(xpbarx, h-12, xpbarx + pxpwidth, h-12, 6, "00 00 FF", 128);
  }
}


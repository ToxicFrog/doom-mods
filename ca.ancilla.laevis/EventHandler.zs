// Event handler for Laevis.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.

class TFLV_EventHandler : StaticEventHandler
{
  override void PlayerSpawned(PlayerEvent evt) {
    PlayerPawn pawn = players[evt.playerNumber].mo;
    if (pawn) {
      pawn.GiveInventoryType("TFLV_PerPlayerStats");
    }
  }
}


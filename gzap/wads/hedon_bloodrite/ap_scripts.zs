// Custom patch for Hedon Bloodrite Archipelago.
class UZAP_Hedon_EventHandler : EventHandler {
  override void WorldLinePreActivated(WorldEvent e) {
    if (level.LevelNum != 1) return;

    // Handling for the power cores in MAP01: Cold Rock.
    // With the default AP behaviour, having even one power core effectively
    // opens nearly the entire map, since you can keep re-summoning it to your
    // inventory to fire the cannon, turn on the elevator, and open the gate.
    // With this handler, we prevent the elevator or gate lines from activating
    // until you have 2 or 3 power cores respectively.
    let line = e.ActivatedLine.Index();
    if (line == 2111) {
      // Elevator switch in west caves
      let region = GZAP_PlayEventHandler.GetState().GetCurrentRegion();
      if (!region) return;
      let key = region.GetKey("InventoryPowerCore");
      if (!key) return;
      if (key.held < 2) {
        console.printf("You need to find a second power core to repair the elevator.");
        e.ShouldActivate = false;
      }
    } else if (line == 6617) {
      // Main gate switch in cold rock
      let region = GZAP_PlayEventHandler.GetState().GetCurrentRegion();
      if (!region) return;
      let key = region.GetKey("InventoryPowerCore");
      if (!key) return;
      if (key.held < 3) {
        console.printf("You need to find a third power core to repair the gate.");
        e.ShouldActivate = false;
      }
    }
  }
}

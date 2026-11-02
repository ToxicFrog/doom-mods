// Custom patch for Hedon Bloodrite Archipelago.
class UZAP_Hedon_EventHandler : EventHandler {
  override void WorldLinePreActivated(WorldEvent e) {
    if (level.LevelNum == 1) { WorldLinePreActivatedMAP01(e); return; }
    if (level.LevelNum == 4) { WorldLinePreActivatedMAP04(e); return; }
  }

  void WorldLinePreActivatedMAP01(WorldEvent e) {
    // Handling for the power cores in MAP01: Cold Rock.
    // With the default AP behaviour, having even one power core effectively
    // opens nearly the entire map, since you can keep re-summoning it to your
    // inventory to fire the cannon, turn on the elevator, and open the gate.
    // With this handler, we prevent the elevator or gate lines from activating
    // until you have 2 or 3 power cores respectively.
    let line = e.ActivatedLine.Index();
    if (line == 2111) {
      // Elevator switch in west caves
      let region = GZAP_RandoState.Get().GetCurrentRegion();
      if (!region) return;
      let key = region.GetKey("InventoryPowerCore");
      if (!key) return;
      if (key.held < 2) {
        console.printf("You need to find a second power core to repair the elevator.");
        e.ShouldActivate = false;
      }
    } else if (line == 6617) {
      // Main gate switch in cold rock
      let region = GZAP_RandoState.Get().GetCurrentRegion();
      if (!region) return;
      let key = region.GetKey("InventoryPowerCore");
      if (!key) return;
      if (key.held < 3) {
        console.printf("You need to find a third power core to repair the gate.");
        e.ShouldActivate = false;
      }
    }
  }

  void WorldLinePreActivatedMAP04(WorldEvent e) {
    let line = e.ActivatedLine;
    // 80 = ACS_Execute, script 43 = iron smelting script
    if (line.special != 80 || line.args[0] != 43) return;

    // How much ore does the player have?
    let region = GZAP_RandoState.Get().GetCurrentRegion();
    if (!region) return;
    let key = region.GetKey("InventoryIronOre");

    // How many iron bars has the player smelted?
    uint seen = 0;
    foreach (location : region.event_based_locations) {
      let loc = GZAP_SpawnLocation(location);
      if (loc && loc.tid == 101) { // iron smelter ingot spawn point
        seen = loc.seen;
        break;
      }
    }

    if (seen >= key.held) {
      console.printf("You need to find more ore to smelt more iron bars.");
      e.ShouldActivate = false;
    }
  }
}

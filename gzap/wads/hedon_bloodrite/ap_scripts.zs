// Custom patch for Hedon Bloodrite Archipelago.
class UZAP_Hedon_EventHandler : EventHandler {
  override void WorldLinePreActivated(WorldEvent e) {
    if (level.LevelNum == 1) { WorldLinePreActivatedMAP01(e); return; }
    if (level.LevelNum == 2) { WorldLinePreActivatedMAP02(e); return; }
    if (level.LevelNum == 4) { WorldLinePreActivatedMAP04(e); return; }
    if (level.LevelNum == 5) { WorldLinePreActivatedMAP05(e); return; }
    // TODO: in MAP06 we may want to use ACS_ScriptCall to restore the player's
    // weapons and consumables on exit, even if they exit via the level select.
    if (level.LevelNum == 9) { WorldLinePreActivatedMAP09(e); return; }
  }

  // Handling for the power cores in MAP01: Cold Rock.
  // With the default AP behaviour, having even one power core effectively
  // opens nearly the entire map, since you can keep re-summoning it to your
  // inventory to fire the cannon, turn on the elevator, and open the gate.
  // With this handler, we prevent the elevator or gate lines from activating
  // until you have 2 or 3 power cores respectively.
  void WorldLinePreActivatedMAP01(WorldEvent e) {
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

  void WorldLinePreActivatedMAP02(WorldEvent e) {
    let line = e.ActivatedLine;
    // 80 = ACS_Execute, script 43 = scribe table script
    if (line.special == 80 && line.args[0] == 42) {
      MAP02ScribeTable(e);

    // Floor_LowerByValue to open the park gate
    } else if (line.Index() == 208 && line.special == 20) {
      MAP02ParkDoor(e);
    }
  }

  // Handling to make opening the park door in MAP02 repeatable.
  // Otherwise it's possible to open the door from the security room, then
  // trigger the big fight, closing it, and end up locked out of the park unless
  // you have access to an alternate path via the east caves or the alchemist.
  void MAP02ParkDoor(WorldEvent e) {
    let line = e.ActivatedLine;
    line.special = 22; // Floor_LowerToNearest
    line.flags |= Line.ML_REPEAT_SPECIAL;
  }

  // Handling for the scribe table in MAP02.
  // The basic rationale here is: we want the player to be able to use up to
  // two earth pigments and three scribe embers to make two earth scrolls and
  // three fire scrolls.
  // If she has more, she should take them to MAP05 instead -- even if this map
  // has been reset and thus the table will accept them.
  // Also, if the player spends one, collects the check, then resets the map and
  // spends another, she should get the second check.
  void MAP02ScribeTable(WorldEvent e) {
    let thing = e.thing;

    // Don't interfere with the use of the table to scribe the scroll of dispel.
    if (thing.CheckInventory("InventoryCanOfEnchantedPurpleInk", 1)) return;

    let apstate = GZAP_RandoState.Get();
    let region = apstate.GetCurrentRegion();

    if (thing.CheckInventory("InventoryMortarOfEarthPigment", 1)) {
      // If the player has any earth pigment in their inventory it will enter
      // the earth scroll branch, even if they've already scribed two.
      // It checks for objects with TID 680 and 681 to see which ones the player
      // has already scribed, so we spawn those in to communicate to the level
      // script which ones have already been done.
      if (!SpawnScrollDebris(region, 184, 680, 182, "IDLabMortarC")) return;
      if (!SpawnScrollDebris(region, 185, 681, 183, "IDLabMortarC")) return;
      console.printf("Take any remaining earth pigment to MAP05: Grove.");
      e.ShouldActivate = false;
      return;
    }

    if (thing.CheckInventory("InventoryBowlOfScribeEmbers", 1)) {
      // We end up here only if they have embers but not pigment or purple ink.
      // Similarly to above, it checks for IDBowl with TID 682, 683, and 684 to
      // see which scrolls have already been scribed, and spawns scrolls at points
      // 189, 190, and 191.
      if (!SpawnScrollDebris(region, 189, 682, 186, "IDBowl")) return;
      if (!SpawnScrollDebris(region, 190, 683, 187, "IDBowl")) return;
      if (!SpawnScrollDebris(region, 191, 684, 188, "IDBowl")) return;
      console.printf("Take any remaining scribe embers to MAP05: Grove.");
      e.ShouldActivate = false;
      return;
    }
  }

  // Handling for the iron smelter in MAP04. Allows the player to get up to four
  // checks from it, but only if they've found four pieces of iron ore.
  void WorldLinePreActivatedMAP04(WorldEvent e) {
    let line = e.ActivatedLine;
    // 80 = ACS_Execute, script 43 = iron smelting script
    if (line.special != 80 || line.args[0] != 43) return;

    // How much ore does the player have?
    let region = GZAP_RandoState.Get().GetCurrentRegion();
    if (!region) return;
    let key = region.GetKey("InventoryIronOre");

    // How many iron bars has the player smelted?
    uint seen = FindLocationByTID(region, 101).seen;

    if (seen >= key.held) {
      console.printf("You need to find more ore to smelt more iron bars.");
      e.ShouldActivate = false;
    }
  }

  // Handling for the scribe table in MAP05.
  // We check the state of the locations in MAP02 first and set up the table to
  // mimic that state. Then we only let the player scribe scrolls if it would
  // leave her with enough leftovers to clean out the MAP02 checks, to avoid
  // softlocks.
  void WorldLinePreActivatedMAP05(WorldEvent e) {
    let line = e.ActivatedLine;
    let thing = e.thing;
    // 80 = ACS_Execute, script 78 = scribe table script
    if (line.special != 80 || line.args[0] != 78) return;

    // Don't interfere with the use of the table to scribe the scroll of dispel.
    if (thing.CheckInventory("InventoryCanOfEnchantedPurpleInk", 1)) return;

    let apstate = GZAP_RandoState.Get();
    let map05 = apstate.GetCurrentRegion();
    let map02 = apstate.GetRegion("MAP02");

    if (thing.CheckInventory("InventoryMortarOfEarthPigment", 1)) {
      // This has three dedicated spots for scroll spawning, of which we use
      // the first two for mimicry (LTR: scroll spawn tid, debris tid, debris
      // spawn TID):
      //  206  680  203
      //  218  687  217
      //  220  688  219
      let required = 3;
      // We unconditionally spawn the debris from the earlier scribings because
      // spawning scrolls at those points will waste the ink without triggering
      // the checks.
      if (SpawnScrollDebrisAlways(map02, 184, 680, 203, "IDLabMortarC")) --required;
      if (SpawnScrollDebrisAlways(map02, 185, 687, 217, "IDLabMortarC")) --required;

      if (!thing.CheckInventory("InventoryMortarOfEarthPigment", required)) {
        console.printf("You should spend your first two earth pigments in MAP02: Plaza.");
        e.ShouldActivate = false;
      }

      SpawnScrollDebris(map05, 220, 688, 219, "IDLabMortarC");
      // At this point either the above wasn't checked, and the player is about
      // to; or it was, she somehow found 4+ pigments, and is about to start
      // writing herself a bunch of full heals. Either way it's fine.
      return;
    }

    if (thing.CheckInventory("InventoryBowlOfScribeEmbers", 1)) {
      let required = 4;
      if (SpawnScrollDebrisAlways(map02, 189, 682, 204, "IDBowl")) --required;
      if (SpawnScrollDebrisAlways(map02, 190, 683, 205, "IDBowl")) --required;
      if (SpawnScrollDebrisAlways(map02, 191, 684, 211, "IDBowl")) --required;
      if (!thing.CheckInventory("InventoryBowlOfScribeEmbers", required)) {
        console.printf("You should spend your first three scribe embers in MAP02: Plaza.");
        e.ShouldActivate = false;
      }
      SpawnScrollDebris(map05, 214, 685, 213, "IDBowl");
      SpawnScrollDebris(map05, 216, 686, 215, "IDBowl");
      return;
    }
  }

  // MAP09 softlock avoidance
  // The tricky bit here is, opening most of the doors leading out and making the
  // last few checks available is handled by script 34, which triggers when you
  // open the crystal key locker.
  // However, opening the doors out of Lith's lab, and activating some of the
  // newly spawned enemies, is triggered by linedefs that check for you carrying
  // the crystal key.
  // If the player has the crystal key, everything works fine.
  // If they don't, we open the door out of the lab anyways; things will be a
  // bit weird but at least the player won't be stuck.
  void WorldLinePreActivatedMAP09(WorldEvent e) {
    let line = e.ActivatedLine;
    // 80 = ACS_Execute, script 34 = open crystal key containment
    if (line.special != 80 || line.args[0] != 34) return;
    if (!GetThingByTID(168)) return; // Already triggered

    level.ExecuteSpecial(
      11, // Door_Open
      players[0].mo, // activator
      null, false, // line info
      154, 16, 0); // parameters
    return;
  }

  Actor GetThingByTID(uint tid) {
    foreach (Actor thing : level.CreateActorIterator(tid)) {
      if (thing) return thing;
    }
    return null;
  }

  // Spawn the debris on the table from scribing a scroll that we've already
  // checked but the game doesn't know about.
  // Returns true if the location was already checked.
  bool SpawnScrollDebris(GZAP_Region region, uint scroll_tid, uint debris_tid, uint debris_spawn, Class<Actor> debris_type) {
    if (!LocationAlreadyTriggered(region, scroll_tid)) return false;
    if (GetThingByTID(debris_tid)) return true;
    SpawnAtSpot(debris_type, debris_spawn, debris_tid);
    return true;
  }

  // As above but spawns in the debris even if the location wasn't already triggered.
  bool SpawnScrollDebrisAlways(GZAP_Region region, uint scroll_tid, uint debris_tid, uint debris_spawn, Class<Actor> debris_type) {
    if (!SpawnScrollDebris(region, scroll_tid, debris_tid, debris_spawn, debris_type)) {
      SpawnAtSpot(debris_type, debris_spawn, debris_tid);
      return false;
    }
    return true;
  }

  void SpawnAtSpot(Class<Actor> type, uint spot_tid, uint tid) {
    let spot = GetThingByTID(spot_tid);
    let thing = Actor.Spawn(type, spot.pos);
    thing.ChangeTID(tid);
  }

  GZAP_SpawnLocation FindLocationByTID(GZAP_Region region, uint tid) {
    foreach (location : region.event_based_locations) {
      let loc = GZAP_SpawnLocation(location);
      if (loc && loc.tid == tid) {
        return loc;
      }
    }
    return null;
  }

  bool LocationAlreadyTriggered(GZAP_Region region, uint tid) {
    let loc = FindLocationByTID(region, tid);
    if (!loc) return false;
    return loc.seen >= loc.count;
  }
}

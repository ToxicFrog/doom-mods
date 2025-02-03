// Play-time event handler.
// At play time, we need to handle a bunch of events:
// - when the player finds an AP item, we need to emit an AP-CHECK
// - we need to listen for events from the AP client and process them
// - we need to let the player move between levels
// - we need to let the player teleport to start of current level, or reset
//   the current level
// - spawn a MapMarker on each marker
// - keys are not, internally, per-level, so when changing levels we need to
//   save all of the player's current keys, remove them from inventory, and
//   replace them with keys for the target level

#namespace GZAP;
#debug on;

#include "./Keyring.zsc"

class ::PlayEventHandler : StaticEventHandler {
  ::Keyring keyrings[MAXPLAYERS];
  override void OnRegister() {}

  override void WorldLoaded(WorldEvent evt) {
    for (uint p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;

      console.printf("init player %d", p);

      // This has the effect that if we reload a game, we end up with the version
      // of the keyring in the player's inventory, even if they reloaded to an
      // earlier state.
      // That's ok, because as soon as we sync again with Archipelago, it'll get
      // updated to match the latest state.
      let pawn = players[p].mo;
      let keyring = ::Keyring(pawn.FindInventory("::Keyring"));
      if (!keyring) {
        keyrings[p] = ::Keyring(pawn.GiveInventoryType("::Keyring"));
      } else {
        keyrings[p] = keyring;
      }
      keyrings[p].UpdateKeys();
    }
  }

  override void WorldUnloaded(WorldEvent evt) {
    if (evt.isSaveGame) return;

    // Hopefully, we're unloading this level because we just completed it.
    // TODO: don't count the level as complete if we're leaving it because
    // we just selected a different level from the level select!
    for (uint p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      keyrings[p].MarkClear(level.MapName);
    }
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.name == "ap-give-blue") {
      keyrings[consoleplayer].AddKey(level.MapName, "BlueCard");
    } else if (evt.name == "ap-give-yellow") {
      keyrings[consoleplayer].AddKey(level.MapName, "YellowCard");
    } else if (evt.name == "ap-give-red") {
      keyrings[consoleplayer].AddKey(level.MapName, "RedCard");
    }
  }
}

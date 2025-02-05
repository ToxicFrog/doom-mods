// Play-time event handler.
// At play time, we need to handle a bunch of events:
// - we need to listen for events from the AP client and process them
// - we need to let the player move between levels
// - we need to let the player teleport to start of current level, or reset
//   the current level

#namespace GZAP;
#debug on;

#include "./Checklist.zsc"
#include "./Keyring.zsc"

class ::PlayEventHandler : StaticEventHandler {
  ::Keyring keyrings[MAXPLAYERS];
  Map<string, ::CheckList> map_to_checks;

  override void OnRegister() {
    // TEST CODE DO NOT EAT
    AddCheck("MAP01", 1, "MAP01 - GreenArmor", false, (592.0, 2624.0, 48.0), 270.0);
    AddCheck("MAP01", 2, "MAP01 - RocketLauncher", false, (832.0, 1600.0, 56.0), 270.0);
    AddCheck("MAP01", 3, "MAP01 - Shotgun", true, (320.0, 368.0, -32.0), 0.0);
  }

  void AddCheck(string map, uint apid, string name, bool progression, Vector3 pos, float angle) {
    let checklist = map_to_checks.Get(map);
    if (!checklist) {
      checklist = new("::CheckList");
      map_to_checks.Insert(map, checklist);
    }
    checklist.AddCheck(apid, name, progression, pos, angle);
  }

  ::CheckInfo FindCheck(Actor thing) {
    let checklist = map_to_checks.Get(level.MapName);
    if (!checklist) return null;
    return checklist.FindCheck(thing.pos, thing.angle);
  }

  // Used by the generated data package to get a handle to the event handler
  // so it can install the location lists.
  static clearscope ::PlayEventHandler Get() {
    return ::PlayEventHandler(Find("::PlayEventHandler"));
  }

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
      // TEST CODE DO NOT EAT
      keyrings[p].MarkMapped("MAP02");
      keyrings[p].MarkChecked("MAP01", 2);
      // END TEST CODE

      keyrings[p].UpdateInventory();
    }

    foreach (Actor thing : ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT)) {
      let info = FindCheck(thing);
      if (info && !IsChecked(info)) {
        thing.Destroy();
        ::CheckPickup check = ::CheckPickup(Actor.Spawn("::CheckPickup", info.pos));
        check.apid = info.apid;
        check.name = info.name;
        check.progression = info.progression;
      }
    }
  }

  // FIXME: not multiplayer safe
  bool IsChecked(::CheckInfo info) {
    return ::Keyring.Get(consoleplayer).IsChecked(level.MapName, info.apid);
  }

  override void WorldUnloaded(WorldEvent evt) {
    if (evt.isSaveGame) return;

    // Hopefully, we're unloading this level because we just completed it.
    // FIXME: don't count the level as complete if we're leaving it because
    // we just selected a different level from the level select!
    for (uint p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      keyrings[p].MarkCleared(level.MapName);
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

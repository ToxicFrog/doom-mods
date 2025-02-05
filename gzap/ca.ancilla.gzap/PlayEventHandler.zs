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
  int skill;
  ::Keyring keyrings[MAXPLAYERS];
  // TODO: probably replace this with something that combines:
  // - the checklist from the data package
  // - the subring from the player's keyring, and
  // - the LevelInfo
  // since we often need all of them in the same place
  Map<string, ::CheckList> map_to_checks;

  void RegisterSkill(int skill) {
    self.skill = skill;
  }

  void RegisterMap(string map) {
    ::Keyring.Get(consoleplayer).GetRing(map);
    return;
  }

  void RegisterKey(string map, string key) {
    return;
  }

  void RegisterCheck(string map, uint apid, string name, bool progression, Vector3 pos, float angle) {
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

  int CountChecks(string map) const {
    let checklist = map_to_checks.Get(map);
    if (!checklist) return 0;
    return checklist.checks.Size();
  }

  // Used by the generated data package to get a handle to the event handler
  // so it can install the location lists.
  static clearscope ::PlayEventHandler Get() {
    return ::PlayEventHandler(Find("::PlayEventHandler"));
  }

  override void WorldLoaded(WorldEvent evt) {
    for (uint p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;

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

    for (uint p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      keyrings[p].MarkCleared(level.MapName);
      Menu.SetMenu("ArchipelagoLevelSelectMenu");
      // FIXME: this lets us select a level, but since we're in the intermission
      // screen by the time it happens, it then proceeds to the next level anyways
      // Probably what we want to actually do is introduce a tiny one-room level
      // into the runtime pk3, and then since we're regenerating the mapinfo anyways,
      // make that the nextlevel of every individual level, so completing a level
      // brings you back there -- and then in WorldLoaded if we're in that level
      // we open the menu.
      // This also means that on entering a level, we can set a flag bit; on
      // returning to the hub from the menu, we can clear it; and on entering
      // the hub, we check if it's set and if so, mark that level as complete.
    }
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.name == "ap-level-select") {
      let idx = evt.args[0];
      let info = LevelInfo.FindLevelByNum(idx);
      if (!info) {
        // oh no, no level of that number, not allowed
        console.printf("No level with number %d found.", idx);
        return;
      }
      level.ChangeLevel(info.MapName, 0, CHANGELEVEL_NOINTERMISSION, skill);
    }
  }
}

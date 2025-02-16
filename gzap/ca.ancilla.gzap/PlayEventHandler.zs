// Play-time event handler.
// At play time, we need to handle a bunch of events:
// - we need to listen for events from the AP client and process them
// - we need to let the player move between levels
// - we need to let the player teleport to start of current level, or reset
//   the current level

#namespace GZAP;
#debug on;

#include "./actors/Check.zsc"
#include "./archipelago/RandoState.zsc"
#include "./archipelago/Region.zsc"
#include "./IPC.zsc"

// TODO: for singleplayer rando, it should be possible to persist the state to
// the save file. We'd need to pull all the state out into a separate object
// and store it in the PlayerPawn. In OnWorldLoaded, if we have an empty state
// and the PlayerPawn doesn't, we overwrite our own state with its state.
class ::PlayEventHandler : StaticEventHandler {
  int skill;
  bool singleplayer;
  // IPC stub for communication with Archipelago.
  ::IPC apclient;
  // Archipelago state manager.
  ::RandoState apstate;

  override void OnRegister() {
    console.printf("PlayEventHandler starting up");
    apclient = ::IPC(new("::IPC"));
    apstate = ::RandoState(new("::RandoState"));
  }

  // N.b. this uses the CVAR skill value, where 0 is ITYTD and 4 is Nightmare.
  void RegisterSkill(int skill, bool singleplayer) {
    self.skill = skill;
    self.singleplayer = singleplayer;
  }

  bool IsSingleplayer() const {
    return self.singleplayer;
  }

  // Used by the generated data package to get a handle to the event handler
  // so it can install the location lists.
  static clearscope ::PlayEventHandler Get() {
    return ::PlayEventHandler(Find("::PlayEventHandler"));
  }

  static clearscope ::RandoState GetState() {
    return ::PlayEventHandler.Get().apstate;
  }

  bool initialized;
  override void WorldLoaded(WorldEvent evt) {
    // Don't initialize IPC until after we're in-game; otherwise NetworkCommandProcess
    // doesn't get called and we end up missing events.
    if (!initialized) {
      initialized = true;
      apclient.Init();
    }

    if (evt.IsSaveGame) {
      ::PerLevelHandler.Get().OnLoadGame();
    } else {
      ::PerLevelHandler.Get().OnNewMap();
    }
  }

  void CheckLocation(int apid, string name) {
    // TODO: we need some way of marking checks unreachable.
    // We can't just check if the player has +NOCLIP because if they do, they
    // can't interact with the check in the first place. So probably we want
    // an 'ap-unreachable' netevent; if set, the next check touched is marked
    // as unreachable, or if the level is exited, all checks in it are marked
    // unreachable.
    ::IPC.Send("CHECK",
      string.format("{ \"id\": %d, \"name\": \"%s\", \"keys\": [%s] }",
        apid, name, apstate.GetCurrentRegion().KeyString()));
    EventHandler.SendNetworkEvent("ap-check", apid);
    apstate.GetCurrentRegion().ClearLocation(apid);
  }

  // TODO: we need an "ap-uncollectable" command for dealing with uncollectable
  // checks, like the flush key in GDT MAP12.
  // This sets a flag, and then:
  // - if a check is collected, that check is marked as uncollectable and the
  //   flag is cleared; or
  // - if the level is exited, all remaining checks in the level are collected
  //   and marked as uncollectable.
  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.name == "ap-level-select") {
      // console.printf("%s %d", evt.name, evt.args[0]);
      let idx = evt.args[0];
      let info = LevelInfo.GetLevelInfo(idx);
      if (!info) {
        // oh no, no level of that number, not allowed
        console.printf("No level with number %d found.", idx);
        return;
      }
      ::PerLevelHandler.Get().early_exit = true;
      level.ChangeLevel(info.MapName, 0, CHANGELEVEL_NOINTERMISSION, skill);
    }
  }

  override void UITick() {
    if (gametic % 35 != 0) return;
    apclient.ReceiveAll();
  }

  override void NetworkCommandProcess(NetworkCommand cmd) {
    // console.printf("NetworkCommandProcess %s", cmd.command);
    if (cmd.command == "ap-ipc:text") {
      string message = cmd.ReadString();
      console.printfEX(PRINT_TEAMCHAT, "%s", message);
    } else if (cmd.command == "ap-ipc:item") {
      int apid = cmd.ReadInt();
      apstate.GrantItem(apid);
    }
  }
}

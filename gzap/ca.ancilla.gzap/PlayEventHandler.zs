// Play-time event handler.
// At play time, we need to handle a bunch of events:
// - we need to listen for events from the AP client and process them
// - we need to let the player move between levels
// - we need to let the player teleport to start of current level, or reset
//   the current level

#namespace GZAP;
#debug off;

#include "./actors/Check.zsc"
#include "./actors/PickupDetector.zsc"
#include "./archipelago/RandoState.zsc"
#include "./archipelago/Region.zsc"
#include "./IPC.zsc"

class ::PlayEventHandler : StaticEventHandler {
  string seed;
  string wadname;
  bool singleplayer;
  bool pretuning;
  // IPC stub for communication with Archipelago.
  ::IPC apclient;
  // Archipelago state manager.
  ::RandoState apstate;

  override void OnRegister() {
    console.printf("Loading gzArchipelago client library version %s", MOD_VERSION());
    apclient = ::IPC(new("::IPC"));
    apstate = ::RandoState.Create();
  }

  override void OnUnregister() {
    apclient.Shutdown();
  }

  void RegisterGameInfo(string slot_name, string seed, string wadname, int filter, bool singleplayer) {
    let filter = 1 << filter;
    console.printf("Archipelago game generated from seed %s for %s playing %s.", seed, slot_name, wadname);
    console.printf("Item/enemy layout: %s. Singleplayer: %s.", ::Util.GetFilterName(filter), singleplayer ? "yes" : "no");
    // Save this information because we need all of it later. Some is sent in
    // XON so the client can get configuration info, some is used in gameplay.
    self.apstate.slot_name = slot_name;
    self.seed = seed;
    self.wadname = wadname;
    self.singleplayer = singleplayer;
    self.apstate.filter = filter;
  }

  bool IsRandomized() {
    return self.apstate.slot_name != "";
  }

  bool IsSingleplayer() const {
    return self.singleplayer && !apclient.IsConnected();
  }

  bool IsPretuning() const {
    return self.pretuning;
  }

  // Used by the generated data package to get a handle to the event handler
  // so it can install the location lists.
  static clearscope ::PlayEventHandler Get() {
    return ::PlayEventHandler(Find("::PlayEventHandler"));
  }

  static clearscope ::RandoState GetState() {
    let peh = ::PlayEventHandler.Get();
    if (!peh) return null;
    return peh.apstate;
  }

  bool initialized;
  override void WorldLoaded(WorldEvent evt) {
    DEBUG("PEH WorldLoaded: %s", level.MapName);
    let region = apstate.GetCurrentRegion();

    // Don't initialize IPC until after we're in-game; otherwise
    // NetworkCommandProcess doesn't get called and we end up missing events.
    // "In-game" here means either any scanned level or the GZAPHUB.
    // In particular we definitely do NOT want to do this on the TITLEMAP,
    // or the player might end up loading their game halfway through initial
    // sync with the client.
    if (!initialized && (region || level.MapName == "GZAPHUB")) {
      initialized = true;
      apclient.Init(self.apstate.slot_name, self.seed, self.wadname);
      apstate.SortLocations();
      ReportWeaponStateChange();
    }

    // Don't run on-level-entry handlers for levels that aren't part of the AP
    // game.
    if (!region) {
      ::PerLevelHandler.Get().InitRandoState(evt.IsSaveGame);
      return;
    } else {
      region.visited = true;
    }

    if (evt.IsSaveGame) {
      ::PerLevelHandler.Get().OnLoadGame();
    } else if (evt.IsReopen) {
      ::PerLevelHandler.Get().OnReopen();
    } else {
      ::PerLevelHandler.Get().OnNewMap();
    }
    ReportVisitStateChange();
  }

  override void WorldUnloaded(WorldEvent evt) {
    let plh = ::PerLevelHandler.Get();
    if (!plh || !evt) return; // Can happen if exiting to new game
    // In normal play NextMap should always be the GZAPHUB. Perhaps in the
    // future (Faithless, Hedon, etc) it might also be another level via direct
    // transit. If it's blank this generally means the player has died without
    // a valid recent save and has elected to restart the game, which we should
    // not treat as a normal exit.
    if (evt.NextMap == "") return;
    plh.OnLevelExit(evt.IsSaveGame, evt.NextMap);
  }

  override void PlayerSpawned(PlayerEvent evt) {
    let p = evt.PlayerNumber;
    if (!playeringame[p]) return;
    if (!players[p].mo) return;
    players[p].mo.GiveInventoryType("::PickupDetector");
  }

  int last_visited;
  void ReportVisitStateChange() {
    Array<string> visited;
    foreach (name, region : apstate.regions) {
      if (region.visited && region.hub) {
        visited.push(name);
      }
    }
    if (visited.Size() != last_visited) {
      last_visited = visited.Size();
      apclient.ReportVisited(visited);
    }
  }

  void ReportWeaponStateChange() {
    // Weapon state change tracking is available only in pretuning mode, since
    // that's less likely to feature players going "lmao I can pistol only the
    // cyberdemon".
    if (!IsPretuning()) return;

    Map<string, int> weapons;
    foreach (item : apstate.items) {
      if (item.IsWeapon() && item.vended > 0) {
        weapons.Insert(item.tag, item.vended);
      }
    }
    apclient.ReportWeapons(weapons);
  }

  void CheckLocation(::Location loc, bool atexit=false) {
    DEBUG("CheckLocation: %d %s", loc.apid, loc.name);

    bool unreachable = false;
    if (ap_scan_unreachable) {
      unreachable = true;
      if (ap_scan_unreachable == 1) {
        cvar.FindCvar("ap_scan_unreachable").SetInt(0);
      }
    }

    string pos = "";
    if (!loc.is_virt) {
      pos = string.format(", \"pos\": [\"%s\",%d,%d,%d]",
        loc.mapname, loc.pos.x, loc.pos.y, loc.pos.z);
    }

    if (unreachable) {
      // Omit the key field and just mark it unreachable.
      ::IPC.Send("CHECK",
        string.format("{ \"id\": %d, \"name\": \"%s\"%s, \"unreachable\": true }",
        loc.apid, loc.name, pos));
    } else if (atexit) {
      // Also omit the key field for atexit checks, since we can't make any
      // assumptions about reachability if the check was gathered via "release
      // on exit" rather than normal play.
      ::IPC.Send("CHECK",
        string.format("{ \"id\": %d, \"name\": \"%s\"%s }",
        loc.apid, loc.name, pos));
    } else {
      // It's a normally reachable check.
      ::IPC.Send("CHECK",
        string.format("{ \"id\": %d, \"name\": \"%s\"%s, \"keys\": [%s] }",
        loc.apid, loc.name, pos, apstate.GetCurrentRegion().KeyString()));
    }

    // In singleplayer, the netevent handler will clear the check for us.
    // In MP, we don't clear it until we get a reply from the server.
    EventHandler.SendNetworkEvent("ap-check", loc.apid);

    // TODO: this crashes if the player goes to start a new game while a game
    // is already in progress. A basic fix for it causes the apstate from the
    // game in progress to carry over to the new game (and the level they were
    // in to be marked as complete). In general we need a better way of handling
    // the player choosing "new game" from in a level, since that shows up as a
    // level exit without savegame(!). Maybe we need a better way of detecting
    // level exits in general, e.g. with line special triggers?
    foreach(player : players) {
      let cv = CVar.GetCVar("ap_show_check_names", player);
      if (!cv || !cv.GetBool() || !player.mo) continue;
      player.mo.A_Print(string.format("Checked %s", loc.name));
    }
  }

  int in_deathlink;
  void ReportDeath(string reason) {
    if (in_deathlink > 0) {
      // Don't send out a deathlink report for a death we received from deathlink!
      in_deathlink -= 1;
      return;
    }

    if (!ap_enable_deathlink) return;

    ::IPC.Send("DEATH",
      string.format("{ \"reason\": \"%s on %s\" }", reason, level.MapName));
  }

  void ApplyDeathLink(string source, string reason) {
    if (!ap_enable_deathlink) return;

    foreach(player : players) {
      if (!player.mo) continue;
      in_deathlink += 1;
      if (reason == "") {
        player.mo.A_Print(string.format("DeathLink triggered by %s", source));
      } else {
        player.mo.A_Print(string.format("DeathLink triggered by %s: %s", source, reason));
      }
      player.mo.A_Die();
    }
  }

  override void NetworkProcess(ConsoleEvent evt) {
    DEBUG("NetworkProcess: %s %d", evt.name, evt.args[0]);
    if (evt.name == "ap-level-select") {
      let idx = evt.args[0];
      let info = LevelInfo.GetLevelInfo(idx);
      if (!info) {
        // oh no, no level of that number, not allowed
        console.printf("No level with number %d found.", idx);
        return;
      }
      ::PerLevelHandler.Get().early_exit = true;
      level.ChangeLevel(info.MapName, 0, CHANGELEVEL_NOINTERMISSION, -1);
    } else if (evt.name.IndexOf("ap-use-item:") == 0) {
      let typename = evt.name.Mid(12);
      apstate.UseItemByName(typename);
    } else if (evt.name == "ap-did-warning") {
      apstate.did_warning = true;
    } else if (evt.name == "ap-debug") {
      apstate.DebugPrint();
    }
  }

  override void UITick() {
    if (gametic % 35 != 0) return;
    apclient.ReceiveAll();
  }

  override void NetworkCommandProcess(NetworkCommand cmd) {
    DEBUG("NetworkCommandProcess: %s", cmd.command);
    if (cmd.command == "ap-ipc:text") {
      string message = cmd.ReadString();
      console.printfEX(PRINT_TEAMCHAT, "%s", message);
    } else if (cmd.command == "ap-ipc:item") {
      int apid = cmd.ReadInt();
      int count = cmd.ReadInt();
      apstate.GrantItem(apid, count);
    } else if (cmd.command == "ap-ipc:checked") {
      int apid = cmd.ReadInt();
      apstate.MarkLocationChecked(apid);
    } else if (cmd.command == "ap-ipc:hint") {
      string mapname = cmd.ReadString();
      string item = cmd.ReadString();
      string player = cmd.ReadString();
      string location = cmd.ReadString();
      DEBUG("HINT: %s (%s) @ %s's %s", item, mapname, player, location);
      apstate.RegisterHint(mapname, item, player, location);
    } else if (cmd.command == "ap-ipc:peek") {
      string mapname = cmd.ReadString();
      string location = cmd.ReadString();
      string player = cmd.ReadString();
      string item = cmd.ReadString();
      DEBUG("PEEK: %s - %s: %s for %s", mapname, location, item, player);
      let region = apstate.GetRegion(mapname);
      if (!region) return; // AP sent us a map name that doesn't exist??
      region.RegisterPeek(location, player, item);
    } else if (cmd.command == "ap-ipc:track") {
      int apid = cmd.ReadInt();
      string track_type = cmd.ReadString();
      apstate.MarkLocationInLogic(apid, track_type);
    } else if (cmd.command == "ap-ipc:death") {
      string source = cmd.ReadString();
      string reason = cmd.ReadString();
      ApplyDeathLink(source, reason);
    } else if (cmd.command == "ap-hint") {
      // Player requested a hint from the level select menu.
      string item = cmd.ReadString();
      ::IPC.Send("CHAT", string.format("{ \"msg\": \"!hint %s\" }", item));
    } else if (cmd.command == "ap-toggle-key") {
      apstate.ToggleKey(cmd.ReadString());
    } else if (cmd.command == "ap-toggle-visited") {
      apstate.ToggleRegionVisited(cmd.ReadString());
      ReportVisitStateChange();
    } else if (cmd.command == "ap-inv-grab-commit") {
      apstate.CommitItemGrabs();
    } else if (cmd.command == "ap-inv-grab-cancel") {
      apstate.CancelItemGrabs();
    } else if (cmd.command == "ap-inv-grab-more") {
      apstate.GrabItem(cmd.ReadString(), 1);
    } else if (cmd.command == "ap-inv-grab-less") {
      apstate.GrabItem(cmd.ReadString(), -1);
    }
  }
}

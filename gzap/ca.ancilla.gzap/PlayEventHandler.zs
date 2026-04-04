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
  // Set if we are currently in the process of leaving a level. Used to distinguish
  // checks being destroyed by level scripting from checks being destroyed because
  // the whole map is being unloaded.
  bool is_exiting;

  override void OnRegister() {
    console.printf("Loading UZArchipelago client library version %s", MOD_VERSION());
    apclient = ::IPC(new("::IPC"));
    apstate = ::RandoState.Create();
    is_exiting = false;
  }

  override void OnUnregister() {
    apclient.Shutdown();
  }

  void RegisterGameInfo(string slot_name, string seed, string wadname, int filter_index, bool singleplayer) {
    console.printf("Archipelago game generated from seed %s for %s playing %s.", seed, slot_name, wadname);
    console.printf("Item/enemy layout: %s. Singleplayer: %s.", ::Util.GetFilterName(filter_index), singleplayer ? "yes" : "no");
    // Save this information because we need all of it later. Some is sent in
    // XON so the client can get configuration info, some is used in gameplay.
    self.apstate.slot_name = slot_name;
    self.seed = seed;
    self.wadname = wadname;
    self.singleplayer = singleplayer;
    self.apstate.filter_index = filter_index;
  }

  bool IsRandomized() {
    return self.apstate.slot_name != "";
  }

  bool IsSingleplayer() const {
    return self.singleplayer;
  }

  bool IsPretuning() const {
    return self.pretuning;
  }

  // Used by the generated data package to get a handle to the event handler
  // so it can install the location lists.
  static clearscope ::PlayEventHandler Get() {
    return ::PlayEventHandler(Find("::PlayEventHandler"));
  }

  bool initialized;
  override void WorldLoaded(WorldEvent evt) {
    DEBUG("PEH WorldLoaded: %s", level.MapName);
    let region = apstate.GetCurrentRegion();
    is_exiting = false;

    // Don't initialize IPC until after we're in-game; otherwise
    // NetworkCommandProcess doesn't get called and we end up missing events.
    // "In-game" here means either any scanned level or the GZAPHUB.
    // In particular we definitely do NOT want to do this on the TITLEMAP,
    // or the player might end up loading their game halfway through initial
    // sync with the client.
    if (!initialized && (region || level.MapName == "GZAPHUB")) {
      initialized = true;
      apstate.ReadStartingInventory();
      apclient.Init(self.apstate.slot_name, self.seed, self.wadname);
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
  }

  override void WorldUnloaded(WorldEvent evt) {
    is_exiting = true;
    let plh = ::PerLevelHandler.Get();
    if (!plh || !evt) return; // Can happen if exiting to new game
    // NextMap might be the GZAPHUB, or, failing that, another level in the same
    // cluster via levelport if playing something like Faithless.
    // If it's blank, this generally means the player has died without a valid
    // recent save and has elected to restart the game, which we should not
    // treat as a normal exit.
    if (evt.NextMap == "") return;
    plh.OnLevelExit(evt.IsSaveGame, evt.NextMap);
  }

  override void PlayerSpawned(PlayerEvent evt) {
    let p = evt.PlayerNumber;
    if (!playeringame[p]) return;
    if (!players[p].mo) return;
    players[p].mo.GiveInventoryType("::PickupDetector");
  }

  void CheckLocation(::Location loc, string reason="", bool atexit=false) {
    DEBUG("CheckLocation[%s]: %d %s", reason, loc.apid, loc.name);

    loc.checked = true;
    bool unreachable = false;
    if (ap_scan_unreachable) {
      unreachable = true;
      if (ap_scan_unreachable == 1) {
        cvar.FindCvar("ap_scan_unreachable").SetInt(0);
      }
    }

    string pos = loc.PositionJSON();
    if (pos) {
      pos = string.format(", \"pos\": %s", pos);
    }

    if (unreachable) {
      // Omit the key field and just mark it unreachable.
      ::IPC.CheckWithoutTuning(loc, pos, true);
    } else if (atexit) {
      // atexit checks aren't necessarily unreachable but nor can we make any
      // assumptions about their tuning.
      ::IPC.CheckWithoutTuning(loc, pos, false);
    } else {
      // It's a normally reachable check.
      if (self.apstate.subregion) {
        ::IPC.CheckWithRegionTuning(loc, pos, self.apstate.subregion.name);
      } else {
        ::IPC.CheckWithKeyTuning(loc, pos, apstate.GetCurrentRegion().KeyString());
      }
    }

    // In MP, the above IPC calls will result in the host eventually responding.
    // In singleplayer, those calls only write to the tuning journal, and all
    // item granting is handled by a netevent handler in the generated pk3.
    // The same handler deals with local-only location checks.
    if (IsSingleplayer() || loc.IsLocal()) {
      EventHandler.SendNetworkEvent("ap-check", loc.apid);
    }

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
      let region = apstate.GetRegion(info.MapName);
      if (region && region.hub && !region.visited) {
        // In classical maps, hub is 0 and thus this doesn't fire.
        // In hub levels, the initially scanned maps(s) will have rank 0 and
        // everything else will have rank 1+, and maps with rank 0 will be flagged
        // as visited on startup, so this lets you levelport to hub entrances
        // but not deeper into the cluster until you make your way there by
        // other means.
        // TODO: this will drop you at whatever the default spawnpoint for the
        // map is, which isn't necessarily the same as the first entrance!
        console.printf("You must visit %s before you can fast travel to it!", info. MapName);
        return;
      }
      ::PerLevelHandler.Get().early_exit = true;
      level.ChangeLevel(info.MapName, 0, CHANGELEVEL_NOINTERMISSION, -1);
    } else if (evt.name.IndexOf("ap-use-item:") == 0) {
      let typename = evt.name.Mid(12);
      apstate.UseItemByName(typename);
    } else if (evt.name == "ap-logic-menu") {
      // We use netevents for this rather than just calling Menu.SetMenu() at the
      // event source, because calling SetMenu() while already inside the same
      // menu doesn't properly redraw it.
      Menu.SetMenu("ArchipelagoLogicMenu");
    } else if (evt.name == "ap-region-menu") {
      Menu.SetMenu("ArchipelagoRegionDefinitionMenu");
    } else if (evt.name == "ap-region-clear") {
      apstate.ClearSubregion();
    } else if (evt.name.IndexOf("ap-region/") == 0) {
      // This is handled here in this somewhat awkward way so that we can define
      // regions from the console with netevent "ap-region/some region name"
      apstate.DefineOrActivateSubregion(evt.name.Mid(10));
    } else if (evt.name == "ap-region-output-all") {
      apstate.OutputSubregions(true);
    } else if (evt.name == "ap-region-output") {
      apstate.OutputSubregions(false);
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
      // In singleplayer, if the client is connected, don't accept any items
      // from it.
      if (self.IsSingleplayer()) return;
      int apid = cmd.ReadInt();
      int count = cmd.ReadInt();
      apstate.GrantItem(apid, count);
    } else if (cmd.command == "ap-ipc:checked") {
      int apid = cmd.ReadInt();
      apstate.MarkLocationCollected(apid);
    } else if (cmd.command == "ap-ipc:hint") {
      if (self.IsSingleplayer()) return;
      string mapname = cmd.ReadString();
      string item = cmd.ReadString();
      string player = cmd.ReadString();
      string location = cmd.ReadString();
      DEBUG("HINT: %s (%s) @ %s's %s", item, mapname, player, location);
      apstate.RegisterHint(mapname, item, player, location);
    } else if (cmd.command == "ap-ipc:peek") {
      string mapname = cmd.ReadString();
      int location_id = cmd.ReadInt();
      string player = cmd.ReadString();
      string item = cmd.ReadString();
      DEBUG("PEEK: %s - %d: %s for %s", mapname, location_id, item, player);
      let region = apstate.GetRegion(mapname);
      if (!region) return; // AP sent us a map name that doesn't exist??
      region.RegisterPeek(location_id, player, item);
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
    } else if (cmd.command == "ap-clear-position") {
      string mapname = cmd.ReadString();
      let region = apstate.GetRegion(mapname);
      if (!region) return;
      region.ClearSavedPosition();
    } else if (cmd.command == "ap-toggle-key") {
      apstate.ToggleKey(cmd.ReadString());
    } else if (cmd.command == "ap-toggle-prereq") {
      if (!apstate.subregion) return;
      apstate.subregion.TogglePrereq(cmd.ReadString());
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

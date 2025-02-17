#namespace GZAP;
#debug on;

#include "./IPC.zsc"
#include "./Util.zsc"

class ::ScanEventHandler : StaticEventHandler {
  Array<string> queue;
  Array<string> done;
  bool scan_enabled;

  override void OnRegister() {
    self.scan_enabled = false;
  }

  // Called when world loading is complete, just before the first tic runs. This
  // happens after PlayerEntered for all players.
  // Unlike PlayerEntered, this is called when loading a savegame, so we try to
  // initialize everyone here to handle the savegame case.
  override void WorldLoaded(WorldEvent evt) {
    if (!scan_enabled) return;
    // As soon as we load into a new map, queue up a scan.
    // We can't do it immediately by calling ScanLevel() or things break?
    EventHandler.SendNetworkEvent("ap-scan", 0, 0, 0);
  }

  override void NetworkProcess(ConsoleEvent evt) {
    if (evt.name == "ap-scan") {
      if (!self.scan_enabled) {
        ::Util.printf("$GZAP_SCAN_STARTING");
        self.scan_enabled = true;
      }
      ScanLevel();
    } else if (evt.name == "ap-next") {
      ScanNext();
    }
  }

  void ScanNext() {
    string nextmap;
    while (queue.size() > 0) {
      nextmap = queue[0];
      if (!LevelScanned(nextmap)) {
        level.ChangeLevel(nextmap, 0, CHANGELEVEL_NOINTERMISSION);
        return;
      } else {
        queue.Delete(0);
      }
    }
    ::IPC.Send("SCAN-DONE", string.format("{ \"skill\": %d }", G_SkillPropertyInt(SKILLP_ACSReturn)));
    ::Util.printf("$GZAP_SCAN_DONE");
    self.scan_enabled = false;
  }

  void EnqueueLevel(string map) {
    string map = map.MakeUpper();
    if (!LevelScanned(map) && LevelInfo.MapExists(map)) {
      ::Util.printf("$GZAP_SCAN_MAP_ENQUEUED", map);
      queue.push(map);
    }
  }

  void MarkDone(string map) {
    string map = map.MakeUpper();
    done.push(map);
  }

  bool LevelScanned(string map) {
    string map = map.MakeUpper();
    return done.find(map) != done.size();
  }

  bool IsSecret(Actor thing) {
    return (thing.cursector.IsSecret() || thing.cursector.WasSecret());
  }

  string bool2str(bool b) {
    return b ? "true" : "false";
  }

  void ScanOutput(string type, string payload) {
    let map = level.MapName.MakeUpper();
    ::IPC.Send(type, string.format("{ \"map\": \"%s\", %s }", map, payload));
  }

  string ScanOutputPosition(Actor thing) {
    return string.format(
      "\"position\": { \"x\": %f, \"y\": %f, \"z\": %f }",
      thing.pos.x, thing.pos.y, thing.pos.z);
  }

  void ScanOutputMonster(Actor thing) {
    if (thing.bCORPSE) return;
    // Not currently implemented
    return;

    ScanOutput("MONSTER", string.format(
      "\"typename\": \"%s\", \"tag\": \"%s\", \"hp\": %d, \"boss\": %s, %s }",
      thing.GetClassName(), thing.GetTag(), thing.health,
      bool2str(thing.bBOSS), ScanOutputPosition(thing)
    ));
  }

  void ScanOutputItem(Actor thing) {
    ScanOutput("ITEM", string.format(
      "\"category\": \"%s\", \"typename\": \"%s\", \"tag\": \"%s\", \"secret\": %s, %s",
      ItemCategory(thing), thing.GetClassName(), thing.GetTag(),
      bool2str(IsSecret(thing)), ScanOutputPosition(thing)
    ));
  }

  void ScanLevel() {
    if (LevelScanned(level.MapName)) {
      // Don't scan the same level more than once. Instead, request that we move
      // on to the next level, if any -- if so it'll queue up both a level change
      // and a scan.
      EventHandler.SendNetworkEvent("ap-next", 0, 0, 0);
      return;
    }

    ::Util.printf("$GZAP_SCAN_MAP_STARTED", level.MapName);
    ScanOutput("MAP", string.format("\"info\": %s", GetMapinfoJSON()));

    int monster_count = 0; int monster_hp = 0;
    int boss_count = 0; int boss_hp = 0;
    int progression_count = 0; int useful_count; int filler_count = 0; int location_count = 0;

    ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
    Actor thing;

    foreach (Actor thing : ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT)) {
      if (thing.bISMONSTER && !thing.bCORPSE) {
        ScanOutputMonster(thing);
      } else if (ItemCategory(thing) != "") {
        ScanOutputItem(thing);
      }
    }

    // TODO: check redirect and cvar_redirect fields as well, which override
    // nextmap based on player inventory or cvar
    MarkDone(level.MapName);
    EnqueueLevel(level.NextMap);
    EnqueueLevel(level.NextSecretMap);
    ::Util.printf("$GZAP_SCAN_MAP_DONE", level.MapName);
    ScanNext();
  }

  string GetMapinfoJSON() {
    let info = level.info;
    let buf = string.format(
        "{ "
        "\"levelnum\": %d, \"title\": \"%s\", \"is_lookup\": %s, "
        "\"sky1\": \"%s\", \"sky1speed\": \"%f\", "
        "\"sky2\": \"%s\", \"sky2speed\": \"%f\", "
        "\"music\": \"%s\", \"music_track\": \"%d\", "
        "\"cluster\": %d, \"flags\": [\"allowrespawn\"",
        info.LevelNum, info.LevelName,
        bool2str(info.flags & LEVEL_LOOKUPLEVELNAME),
        info.SkyPic1, info.SkySpeed1,
        info.SkyPic2, info.SkySpeed2,
        info.Music, info.MusicOrder,
        info.Cluster);

    buf = buf .. (info.flags & LEVEL_MAP07SPECIAL ? ", \"map07special\"" : "");
    buf = buf .. (info.flags & LEVEL_DOUBLESKY ? ", \"doublesky\"" : "");
    buf = buf .. (info.flags2 & LEVEL2_INFINITE_FLIGHT ? ", \"infiniteflightpowerup\"" : "");

    return buf .. "]}";
  }

  bool IsArtifact(Actor thing) {
    string cls = thing.GetClassName();
    return cls.left(4) == "Arti";
  }

  // TODO: we can use inventory flags for this better than class hierarchy in many cases.
  // INVENTORY.AUTOACTIVATE - item activates when picked up
  // .INVBAR - item goes to the inventory screen and can be used later
  // .BIGPOWERUP - item is particularly powerful
  // .ISHEALTH, .ISARMOR - as it says
  // .HUBPOWER, .PERSISTENTPOWER, and .InterHubAmount allow carrying between levels
  // .COUNTITEM - counts towards the % items collected stat
  // there's also sv_unlimited_pickup to remove all limits on ammo capacity(!)
  // We might want to remove AUTOACTIVATE and add INVBAR to some stuff in the
  // future so the player can keep it until particularly useful.
  string ItemCategory(Actor thing) {
    if (thing is "DehackedPickup") {
      // TODO: Ideally, we'd call DetermineType() on it here to figure out what
      // the underlying type of the DEH item is. However, DetermineType() is
      // private, so the only way we can figure that out is by creating an
      // actor to touch it and then calling CallTryPickup() on it, which will
      // cause the real item to CallTryPickup on the actor -- which can probably
      // be made to work, but I'm not doing it right now.
    }
    if (thing is "Key" || thing is "PuzzleItem") {
      return "key"; // TODO: allow duplicate PuzzleItems but not Keys
    } else if (thing is "Weapon" || thing is "WeaponPiece") {
      return "weapon";
    } else if (thing is "BackpackItem") {
      return "big-ammo";
    } else if (thing is "MapRevealer") {
      return "map";
    } else if (thing is "PowerupGiver" || thing is "Berserk") {
      return "powerup";
    } else if (thing is "BasicArmorPickup" || thing is "Megasphere") {
      return "big-armor";
    } else if (thing is "BasicArmorBonus") {
      return "small-armor";
    } else if (thing is "Health") {
      let h = Health(thing);
      return h.Amount < 50 ? "small-health" : "big-health";
    } else if (thing is "Ammo") {
      let a = Ammo(thing);
      return a.Amount < a.MaxAmount/5 ? "small-ammo" : "medium-ammo";
    } else if (thing is "Mana3") {
      return "big-ammo";
    } else if (thing is "HealthPickup" || IsArtifact(thing)) {
      return "tool";
    }

    return "";
  }
}
// APDoom uses the following classifications:
// - keys and weapons are progression items
// - powerups, ammo, health, and armor are filler
// - level maps are filler
// - each level has a synthetic "access granted", "level complete", and "computer map" item generated for it

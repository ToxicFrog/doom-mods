#namespace GZAP;
#debug on;

class ::EventHandler : StaticEventHandler {
  Array<string> queue;
  Array<string> done;
  Array<string> secret_levels;

  override void OnRegister() {
    console.printf("Starting up GZAP Event Handler");
  }

  // Called when world loading is complete, just before the first tic runs. This
  // happens after PlayerEntered for all players.
  // Unlike PlayerEntered, this is called when loading a savegame, so we try to
  // initialize everyone here to handle the savegame case.
  override void WorldLoaded(WorldEvent evt) {
    console.printf("WorldLoaded");
    // As soon as we load into a new map, queue up a scan.
    // We can't do it immediately by calling ScanLevel() or things break?
    EventHandler.SendNetworkEvent("ap-scan", 0, 0, 0);
  }

  override void NetworkProcess(ConsoleEvent evt) {
    // console.printf("[Archipelago] netevent: %s", evt.name);
    if (evt.name == "ap-scan") {
      // console.printf("[Archipelago] Scan requested.");
      ScanLevel();
    } else if (evt.name == "ap-next") {
      // console.printf("[Archipelago] Nextmap requested.");
      ScanNext();
    }
  }

  void ScanNext() {
    string nextmap;
    while (queue.size() > 0) {
      nextmap = queue[queue.size()-1];
      if (!LevelScanned(nextmap)) {
        // console.printf("[Archipelago] Changing to %s", nextmap);
        level.ChangeLevel(nextmap, 0, CHANGELEVEL_NOINTERMISSION);
        return;
      } else {
        // console.printf("[Archipelago] Skipping %s as it's already been scanned", nextmap);
        queue.pop();
      }
    }
    console.printf("[Archipelago] No more maps to scan.");
  }

  void EnqueueLevel(string map) {
    if (!LevelScanned(map) && LevelInfo.MapExists(map)) {
      console.printf("[Archipelago] Enqueing %s", map);
      queue.push(map);
    }
  }

  bool LevelScanned(string map) {
    return done.find(map) != done.size();
  }

  bool IsSecretLevel(string map) {
    return secret_levels.find(map) != secret_levels.size();
  }

  bool IsSecret(Actor thing) {
    return (thing.cursector.IsSecret() || thing.cursector.WasSecret());
  }

  string bool2str(bool b) {
    return b ? "true" : "false";
  }

  void ScanOutput(string payload) {
    console.printf("AP SCAN { :map \"%s\" %s }", level.MapName, payload);
  }

  void ScanOutputLocation(Actor thing, string payload) {
    ScanOutput(string.format(
      ":location { :x %f :y %f :z %f :angle %f :secret %s %s }",
      thing.pos.x, thing.pos.y, thing.pos.z, thing.angle, bool2str(IsSecret(thing)), payload
    ));
  }

  void ScanOutputMonster(Actor thing) {
    if (thing.bCORPSE) return;

    ScanOutputLocation(thing, string.format(
      ":monster { :class \"%s\" :hp %d :boss %s }",
      thing.GetClassName(), thing.health, bool2str(thing.bBOSS)
    ));
  }

  void ScanOutputItem(Actor thing) {
    ScanOutputLocation(thing, string.format(
      ":item { :category %s :class \"%s\" :tag \"%s\" }",
      ItemCategory(thing), thing.GetClassName(), thing.GetTag()
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

    console.printf("[Archipelago] Beginning scan of %s", level.MapName);
    ScanOutput(string.format(
      ":info { :title \"%s\" :secret %s }",
      level.LevelName, bool2str(IsSecretLevel(level.MapName))
    ));

    int monster_count = 0; int monster_hp = 0;
    int boss_count = 0; int boss_hp = 0;
    int progression_count = 0; int useful_count; int filler_count = 0; int location_count = 0;

    ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
    Actor thing;

    while (thing = Actor(it.next())) {
      if (thing.bISMONSTER && !thing.bCORPSE) {
        ScanOutputMonster(thing);
      } else if (ItemCategory(thing) != "") {
        ScanOutputItem(thing);
      }
    }

    done.push(level.MapName);
    EnqueueLevel(level.NextMap);
    if (level.NextMap == level.NextSecretMap) {
      console.printf("[Archipelago] Scan completed. Next map: %s", level.NextMap);
    } else {
      EnqueueLevel(level.NextSecretMap);
      self.secret_levels.push(level.NextSecretMap);
      console.printf("[Archipelago] Scan completed. Next maps: %s, %s",
        level.NextSecretMap, level.NextMap);
    }
    ScanNext();
  }

  bool IsArtifact(Actor thing) {
    string cls = thing.GetClassName();
    return cls.left(4) == "Arti";
  }

  string ItemCategory(Actor thing) {
    if (thing is "Key" || thing is "PuzzleItem") {
      return ":key";
    } else if (thing is "Weapon" || thing is "WeaponPiece") {
      return ":weapon";
    } else if (thing is "BackpackItem") {
      return ":upgrade";
    } else if (thing is "MapRevealer") {
      return ":map";
    } else if (thing is "PowerupGiver") {
      return ":powerup";
    } else if (thing is "BasicArmorPickup") {
      return ":big-armor";
    } else if (thing is "BasicArmorBonus") {
      return ":small-armor";
    } else if (thing is "Health") {
      let h = Health(thing);
      return h.Amount < 20 ? ":small-health" : ":big-health";
    } else if (thing is "Ammo") {
      let a = Ammo(thing);
      return a.Amount < a.MaxAmount/10 ? ":small-ammo" : ":big-ammo";
    } else if (thing is "HealthPickup" || IsArtifact(thing)) {
      return ":tool";
    }

    return "";
  }
}
// APDoom uses the following classifications:
// - keys and weapons are progression items
// - powerups, ammo, health, and armor are filler
// - level maps are filler
// - each level has a synthetic "access granted", "level complete", and "computer map" item generated for it

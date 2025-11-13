#namespace TFLV;

class ::Debug : Object play {
  static void DebugCommand(::GunBonsaiService service, int player, string cmd, uint arg) {
    Array<string> argv;
    cmd.split(argv, ",");
    if (argv.Size() <= 1) {
      console.printf("Insufficient args.");
    }
    // 0: bonsai-debug, 1: <command>, 2: args...
    if (argv[1] == "info") {
      ShowInfoConsole(players[player].mo);
    } else if (argv[1] == "w-up" && argv.size() >= 3) {
      let upgrade = argv[2];
      if (upgrade.IndexOf(":"..":") == 0) upgrade = "TFLV_Upgrade_" .. upgrade.Mid(2);
      service.GetInt("add-w-upgrade", upgrade, player, arg, null);
    } else if (argv[1] == "p-up" && argv.size() >= 3) {
      let upgrade = argv[2];
      if (upgrade.IndexOf(":"..":") == 0) upgrade = "TFLV_Upgrade_" .. upgrade.Mid(2);
      service.GetInt("add-p-upgrade", upgrade, player, arg);
    } else if (argv[1] == "w-xp") {
      service.GetDouble("add-w-xp", "", player, arg, null);
    } else if (argv[1] == "p-xp") {
      service.GetDouble("add-p-xp", "", player, arg);
    } else if (argv[1] == "allupgrades") {
      AddAllUpgrades(service, player);
    } else if (argv[1] == "reset") {
      console.printf("Fully resetting all weapon info.");
      let stats = ::PerPlayerStats.GetStatsFor(players[player].mo);
      stats.weapons.clear();
      stats.weaponinfo_dirty = true;
      stats.XP = 0;
      stats.level = 0;
      stats.upgrades = null;
      stats.Initialize(stats.proxy);
    } else {
      console.printf("Unknown or malformed debug command: %s", argv[1]);
    }
  }

  static void ShowInfoConsole(Actor pawn) {
    ::CurrentStats stats;
    if (!::PerPlayerStats.GetStatsFor(pawn).GetCurrentStats(stats)) {
      console.printf("Error getting current stats for player.");
      return;
    }
    console.printf("Player:\n    Level %d (%d/%d XP)",
      stats.plvl, stats.pxp, stats.pmax);
    stats.pupgrades.DumpToConsole("    ");
    console.printf("%s (%s):\n    Level %d (%d/%d XP)",
      stats.winfo.wpnClass, stats.wname, stats.wlvl, stats.wxp, stats.wmax);
    stats.wupgrades.DumpToConsole("    ");
    stats.winfo.DumpTypeInfo();
  }

  static void AddAllUpgrades(::GunBonsaiService service, int player) {
    let registry = ::Upgrade::Registry.GetRegistry();
    for (uint i = 0; i < registry.upgrades.size(); ++i) {
      service.GetInt("add-w-upgrade", registry.upgrades[i].GetClassName(), player, 1, null);
      service.GetInt("add-p-upgrade", registry.upgrades[i].GetClassName(), player, 1);
    }
  }
}

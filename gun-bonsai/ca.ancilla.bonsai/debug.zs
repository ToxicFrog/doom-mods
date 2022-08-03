#namespace TFLV;

class ::Debug : Object play {
  static void DebugCommand(Actor pawn, string cmd, uint arg) {
    Array<string> argv;
    cmd.split(argv, ",");
    // 0: bonsai-debug, 1: <command>, 2: args...
    if (argv[1] == "w-up" && argv.size() >= 3) {
      AddWeaponUpgrade(pawn, argv[2], arg);
    } else if (argv[1] == "p-up" && argv.size() >= 3) {
      AddPlayerUpgrade(pawn, argv[2], arg);
    } else if (argv[1] == "w-xp") {
      AddWeaponXP(pawn, arg);
    } else if (argv[1] == "p-xp") {
      AddPlayerXP(pawn, arg);
    } else {
      console.printf("Unknown or malformed debug command: %s", argv[1]);
    }
  }

  static void AddWeaponUpgrade(Actor pawn, string upgrade, uint n) {
    if (n <= 0) n = 1;
    if (upgrade.IndexOf(":"..":") == 0) upgrade = "TFLV_Upgrade_" .. upgrade.Mid(2);
    class<::Upgrade::BaseUpgrade> cls = upgrade;
    if (!cls) {
      console.printf("%s either doesn't exist or isn't a subclass of BaseUpgrade");
      return;
    }
    console.printf("Adding %d levels of %s to current weapon.", n, upgrade);
    ::PerPlayerStats.GetStatsFor(pawn).GetInfoForCurrentWeapon().upgrades.Add(upgrade, n);
  }

  static void AddPlayerUpgrade(Actor pawn, string upgrade, uint n) {
    if (n <= 0) n = 1;
    if (upgrade.IndexOf(":"..":") == 0) upgrade = "TFLV_Upgrade_" .. upgrade.Mid(2);
    class<::Upgrade::BaseUpgrade> cls = upgrade;
    if (!cls) {
      console.printf("%s either doesn't exist or isn't a subclass of BaseUpgrade", upgrade);
      return;
    }
    console.printf("Adding %d levels of %s to player.", n, upgrade);
    ::PerPlayerStats.GetStatsFor(pawn).upgrades.Add(upgrade, n);
  }

  static void AddWeaponXP(Actor pawn, uint xp) {
    console.printf("Add %d XP to current weapon.", xp);
    ::PerPlayerStats.GetStatsFor(pawn).AddXP(xp);
  }

  static void AddPlayerXP(Actor pawn, uint xp) {
    console.printf("Add %d XP to player.", xp);
    ::PerPlayerStats.GetStatsFor(pawn).XP += xp;
  }
}

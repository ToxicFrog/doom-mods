// RPC service for Gun Bonsai.
// The first string argument to a service call is always the name of the function
// to invoke, and the int argument is the index of the player to affect. The object
// argument, if specified, is the weapon to affect; otherwise the player's currently
// wielded weapon is affected. The behaviour is undefined if you pass a weapon
// the not in the player's inventory, but probably nothing good will happen.
//
// Supported functions are:
//
//    GetInt("add-w-upgrade", string upgrade_name, int player, float levels, Object? weapon) -> upgrade level
// Add or level-up a weapon upgrade. Upgrade_name should be the class name of the
// upgrade. Returns the total level of the upgrade.
//
//    GetInt("add-p-upgrade", string upgrade_name, int player, float levels) -> upgrade level
// Add or level-up a player upgrade.
//
//    GetDouble("add-w-xp", "", int player, float xp, Object? weapon) -> total xp
// Add XP to the specified weapon (or the currently wielded weapon if unspecified).
// Returns the weapon's total XP.
//
//    GetDouble("add-p-xp", "", int player, float xp) -> total xp
// Add XP to the player, without leveling up their weapon.

#namespace TFLV;
#debug off;

class ::GunBonsaiService : Service play {
  ::EventHandler handler;

  void Init(::EventHandler handler) {
    self.handler = handler;
  }

  override int GetInt(String fn, String upgrade, int p, double n, Object wpn) {
    if (fn == "add-w-upgrade") {
      return AddWeaponUpgrade(p, upgrade, n, Weapon(wpn));
    } else if (fn == "add-p-upgrade") {
      return AddPlayerUpgrade(p, upgrade, n);
    } else {
      console.printf("GunBonsaiService: unknown rpc name GetInt[%s]", fn);
      return 0;
    }
  }

  int AddWeaponUpgrade(int p, string upgrade, int n, Weapon wpn) {
    if (n <= 0) {
      console.printf("GunBonsaiService: can't add <= 0 upgrade levels");
      return 0;
    }
    class<::Upgrade::BaseUpgrade> cls = upgrade;
    if (!cls) {
      console.printf("GunBonsaiService: %s either doesn't exist or isn't a subclass of BaseUpgrade", upgrade);
      return 0;
    }
    let stats = handler.playerstats[p];
    let info = wpn ? stats.GetInfoFor(wpn) : stats.GetInfoForCurrentWeapon();
    console.printf("Adding %d levels of %s to %s's %s.", n, upgrade, players[p].GetUserName(), info.wpn.GetTag());
    let power = info.upgrades.Add(upgrade, n);
    power.OnActivate(stats, info);
    return power.level;
  }

  int AddPlayerUpgrade(int p, string upgrade, uint n) {
    if (n <= 0) {
      console.printf("GunBonsaiService: can't add <= 0 upgrade levels");
      return 0;
    }
    class<::Upgrade::BaseUpgrade> cls = upgrade;
    if (!cls) {
      console.printf("GunBonsaiService: %s either doesn't exist or isn't a subclass of BaseUpgrade", upgrade);
      return 0;
    }
    console.printf("Adding %d levels of %s to %s.", n, upgrade, players[p].GetUserName());
    let stats = handler.playerstats[p];
    let power = stats.upgrades.Add(upgrade, n);
    power.OnActivate(stats, null);
    return power.level;
  }

  override double GetDouble(String fn, String upgrade, int p, double n, Object wpn) {
    if (fn == "add-w-xp") {
      return AddWeaponXP(p, n, Weapon(wpn));
    } else if (fn == "add-p-xp") {
      return AddPlayerXP(p, n);
    } else {
      console.printf("GunBonsaiService: unknown rpc name GetDouble[%s]", fn);
      return 0;
    }
  }

  double AddWeaponXP(int p, double xp, Weapon wpn = null) {
    DEBUG("Adding %d XP to %s's %s.", n, players[p].GetUserName(), TAG(info.wpn));
    let stats = handler.playerstats[p];
    let info = wpn ? stats.GetInfoFor(wpn) : stats.GetInfoForCurrentWeapon();
    info.AddXP(xp);
    return info.xp;
  }

  double AddPlayerXP(int p, double xp) {
    DEBUG("Adding %d XP to %s.", n, players[p].GetUserName());
    let stats = handler.playerstats[p];
    stats.xp += xp;
    return stats.xp;
  }
}

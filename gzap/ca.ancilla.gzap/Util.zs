#namespace GZAP;

class ::Util play {
  // Eurgh this is gross, but zscript doesn't let us have va_list so...
  static void printf(string msg, string arg1 = "", string arg2 = "", string arg3 = "") {
    console.printf(
      StringTable.Localize(msg),
      StringTable.Localize(arg1),
      StringTable.Localize(arg2),
      StringTable.Localize(arg3));
  }

  // TODO: this is noisy and largely unnecessary in multiplayer games...
  static void announce(string msg, string arg1 = "", string arg2 = "", string arg3 = "") {
    return;
    let text = string.format(
      StringTable.Localize(msg),
      StringTable.Localize(arg1),
      StringTable.Localize(arg2),
      StringTable.Localize(arg3));

    for (int p = 0; p < MAXPLAYERS; ++p) {
      if (!playeringame[p]) continue;
      if (!players[p].mo) continue;
      players[p].mo.A_PrintBold(text);
    }
  }
}

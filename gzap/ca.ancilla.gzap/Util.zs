#namespace GZAP;

class ::Util {
  // Eurgh this is gross, but zscript doesn't let us have va_list so...
  static void printf(string msg, string arg1 = "", string arg2 = "", string arg3 = "") {
    console.printf(
      StringTable.Localize(msg),
      StringTable.Localize(arg1),
      StringTable.Localize(arg2),
      StringTable.Localize(arg3));
  }
}
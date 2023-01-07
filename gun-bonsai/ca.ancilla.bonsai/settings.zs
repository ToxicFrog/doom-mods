enum TFLV_WhichGuns {
  TFLV_NO_GUNS,
  TFLV_BASIC_GUNS,
  TFLV_LEGENDARY_GUNS,
  TFLV_ALL_GUNS
}

enum TFLV_UpgradeBindingMode {
  TFLV_BIND_WEAPON,
  TFLV_BIND_WEAPON_INHERITABLE,
  TFLV_BIND_CLASS
}

enum TFLV_VfxMode {
  TFLV_VFX_OFF,
  TFLV_VFX_REDUCED,
  TFLV_VFX_FULL
}

// Interface to the CVar settings for this mod.
class TFLV_Settings : Object {
  static int GetInt(string name) {
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetInt();
    return -1;
  }

  static double GetDouble(string name) {
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetFloat();
    return -1.0;
  }

  static bool GetBool(string name) {
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetBool();
    return false;
  }

  static string GetString(string name) {
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetString();
    return "";
  }

  static string, string, string hud_skin() {
    static const string skins[] = { "", "A", "B", "C" };
    let skin = GetInt("bonsai_hud_skin");
    if (skin == 0 || skin > 3) return "","","";
    return string.format("LHUD%c", skin+0x40),
           string.format("LHDW%c", skin+0x40),
           string.format("LHDP%c", skin+0x40);
  }

  static double, double, double, double, uint hud_params() {
    return GetDouble("bonsai_hud_x"),
        GetDouble("bonsai_hud_y"),
        GetDouble("bonsai_hud_size"),
        GetDouble("bonsai_hud_alpha"),
        GetInt("bonsai_hud_mirror");
  }

  static uint, uint, uint hud_colours() {
    // These are in RGB format rather than ARGB format, so add the alpha channel.
    return GetInt("bonsai_hud_rgb_frame") | 0xFF000000,
           GetInt("bonsai_hud_rgb_weapon") | 0xFF000000,
           GetInt("bonsai_hud_rgb_player") | 0xFF000000;
  }

  static bool levelup_flash() {
    return GetBool("bonsai_levelup_flash");
  }

  static uint vfx_mode() {
    return GetInt("bonsai_vfx_mode");
  }

  static string levelup_sound() {
    // Must be kept in sync with the GunBonsaiLevelUpSoundOption in MENUDEF
    static const string sounds[] = { "", "bonsai/gunlevelup", "misc/secret", "misc/teleport" };
    let mode = GetInt("bonsai_levelup_sound_mode");
    if (mode < 0) return GetString("bonsai_levelup_sound");
    if (mode > 3) return "";
    return sounds[mode];
  }

  static bool have_legendoom() {
    // If we just do cls = "LDPistol" it will get checked at compile time; we
    // need to defer this to runtime so that everything has a chance to load.
    string ldpistol = "LDPistol";
    class<Actor> cls = ldpistol;
    return cls != null;
  }
}

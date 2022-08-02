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

  static int gun_levels_per_player_level() {
    return GetInt("bonsai_gun_levels_per_player_level");
  }
  static int gun_levels_per_ld_effect() {
    return GetInt("bonsai_gun_levels_per_ld_effect");
  }
  static int base_level_cost() {
    return GetInt("bonsai_base_level_cost");
  }
  static double level_cost_mul_for(string flagname) {
    return GetDouble("bonsai_level_cost_mul_for_"..flagname);
  }
  static double damage_to_xp_factor() {
    return GetDouble("bonsai_damage_to_xp_factor");
  }
  static double score_to_xp_factor() {
    return GetDouble("bonsai_score_to_xp_factor");
  }
  static TFLV_UpgradeBindingMode upgrade_binding_mode() {
    return GetInt("bonsai_upgrade_binding_mode");
  }
  static TFLV_WhichGuns which_guns_can_learn() {
    return GetInt("bonsai_which_guns_can_learn");
  }
  static TFLV_WhichGuns which_guns_can_replace() {
    return GetInt("bonsai_which_guns_can_learn");
  }
  static int base_ld_effect_slots() {
    return GetInt("bonsai_base_ld_effect_slots");
  }
  static int bonus_ld_effect_slots() {
    return GetInt("bonsai_bonus_ld_effect_slots");
  }
  static bool ignore_gun_rarity() {
    return GetBool("bonsai_ignore_gun_rarity");
  }
  static bool use_builtin_actors() {
    return GetBool("bonsai_use_builtin_actors");
  }

  static int screenblocks() {
    return GetInt("screenblocks");
  }

  static double, double, double, uint hud_params() {
    return GetDouble("bonsai_hud_x"), GetDouble("bonsai_hud_y"), GetDouble("bonsai_hud_size"), GetInt("bonsai_hud_mirror");
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

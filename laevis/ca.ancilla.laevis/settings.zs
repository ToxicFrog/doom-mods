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

  static bool GetBool(string name){
    let cv = CVar.FindCVar(name);
    if (cv) return cv.GetBool();
    return false;
  }

  static int gun_levels_per_player_level() {
    return GetInt("laevis_gun_levels_per_player_level");
  }
  static int gun_levels_per_ld_effect() {
    return GetInt("laevis_gun_levels_per_ld_effect");
  }
  static int base_level_cost() {
    return GetInt("laevis_base_level_cost");
  }
  static double level_cost_mul_for(string flagname) {
    return GetDouble("laevis_level_cost_mul_for_"..flagname);
  }
  static double damage_to_xp_factor() {
    return GetDouble("laevis_damage_to_xp_factor");
  }
  static double score_to_xp_factor() {
    return GetDouble("laevis_score_to_xp_factor");
  }
  static TFLV_UpgradeBindingMode upgrade_binding_mode() {
    return GetInt("laevis_upgrade_binding_mode");
  }
  static TFLV_WhichGuns which_guns_can_learn() {
    return GetInt("laevis_which_guns_can_learn");
  }
  static TFLV_WhichGuns which_guns_can_replace() {
    return GetInt("laevis_which_guns_can_learn");
  }
  static int base_ld_effect_slots() {
    return GetInt("laevis_base_ld_effect_slots");
  }
  static int bonus_ld_effect_slots() {
    return GetInt("laevis_bonus_ld_effect_slots");
  }
  static bool ignore_gun_rarity() {
    return GetBool("laevis_ignore_gun_rarity");
  }
  static bool use_builtin_actors() {
    return GetBool("laevis_use_builtin_actors");
  }

  static int screenblocks() {
    return GetInt("screenblocks");
  }

  static double, double, double, uint hud_params() {
    return GetDouble("laevis_hud_x"), GetDouble("laevis_hud_y"), GetDouble("laevis_hud_size"), GetInt("laevis_hud_mirror");
  }
  static uint, uint, uint hud_colours() {
    // These are in RGB format rather than ARGB format, so add the alpha channel.
    return GetInt("laevis_hud_rgb_frame") | 0xFF000000,
           GetInt("laevis_hud_rgb_weapon") | 0xFF000000,
           GetInt("laevis_hud_rgb_player") | 0xFF000000;
  }
}

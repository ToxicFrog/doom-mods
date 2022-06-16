enum TFLV_WhichGuns {
  TFLV_NO_GUNS,
  TFLV_BASIC_GUNS,
  TFLV_LEGENDARY_GUNS,
  TFLV_ALL_GUNS
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
  static double player_damage_bonus() {
    return GetDouble("laevis_player_damage_bonus");
  }
  static double player_defence_bonus() {
    return GetDouble("laevis_player_defence_bonus");
  }
  static int base_level_cost() {
    return GetInt("laevis_base_level_cost");
  }
  static double gun_damage_bonus() {
    return GetDouble("laevis_gun_damage_bonus");
  }
  static double level_cost_mul_for(string flagname) {
    return GetDouble("laevis_level_cost_mul_for_"..flagname);
  }
  static bool use_score_for_xp() {
    return GetBool("laevis_use_score_for_xp");
  }
  static bool score_to_xp_factor() {
    return GetDouble("laevis_score_to_xp_factor");
  }
  static bool remember_missing_weapons() {
    return GetDouble("laevis_remember_weapon_xp");
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

  static int screenblocks() {
    return GetInt("screenblocks");
  }
}

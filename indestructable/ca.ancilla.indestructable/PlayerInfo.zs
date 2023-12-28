#namespace TFIS;
#debug off;

enum ::CompletionRequirements {
  COMPLETION_NONE = 0,
  COMPLETION_ALL_KILLS = 1,
  COMPLETION_ALL_SECRETS = 2,
  COMPLETION_KILLS_OR_SECRETS = 3,
  COMPLETION_KILLS_OR_SECRETS_STACKING = 4,
  COMPLETION_KILLS_AND_SECRETS = 5
}

class ::PlayerInfo : Object play {
  int lives;
  int lives_reported; // as of last time ReportLives() was called
  int charge; // for the incoming damage -> lives feature
  Array<string> levels_cleared;
  ::IndestructableForce force;

  static ::PlayerInfo Create() {
    ::PlayerInfo info = new("::PlayerInfo");
    info.GiveStartingLives();
    return info;
  }

  void GiveStartingLives() {
    lives = indestructable_gun_bonsai_mode ? 0 : indestructable_starting_lives;
    lives_reported = 0;
  }

  void Message(string msg) {
    force.Message(msg);
  }

  bool LevelSeen(string md5) {
    return levels_cleared.find(md5) != levels_cleared.size();
  }

  // Returns what multiplier should be applied to the end-of-level life bonus.
  // This is normally 0 (no bonus) or 1 (full bonus), but if the player is using
  // stacking completion requirements, it might be 2.
  uint BonusCount() {
    let all_kills = level.killed_monsters >= level.total_monsters;
    let all_secrets = level.found_secrets >= level.total_secrets;
    switch (indestructable_completion_requirement) {
      case COMPLETION_NONE: return 1;
      case COMPLETION_ALL_KILLS: return all_kills ? 1 : 0;
      case COMPLETION_ALL_SECRETS: return all_secrets ? 1 : 0;
      case COMPLETION_KILLS_OR_SECRETS: return all_kills || all_secrets ? 1 : 0;
      case COMPLETION_KILLS_AND_SECRETS: return all_kills && all_secrets ? 1 : 0;
      case COMPLETION_KILLS_OR_SECRETS_STACKING:
        if (all_kills && all_secrets) return 2;
        else if (all_kills || all_secrets) return 1;
        return 0;
      default: return 1;
    }
  }

  // Called when clearing a level. md5 is the md5 checksum of the level, used
  // to ensure we don't award lives for clearing the same level twice.
  void AddLevelClearLives(string md5) {
    DEBUG("AddLevelClearLives(%s)", md5);
    if (LevelSeen(md5)) return;
    let bonus_count = BonusCount();
    DEBUG("bonus_count = %d", bonus_count);
    if (!bonus_count) return;

    levels_cleared.push(md5);
    AdjustLives(indestructable_lives_per_level * bonus_count, true);
    if (lives < indestructable_min_lives_per_level) {
      AdjustLives(indestructable_min_lives_per_level - lives, false);
    }
  }

  // Called when a boss is killed.
  void AddBossKillLives() {
    AdjustLives(indestructable_lives_per_boss, true);
  }

  void AddDamageCharge(uint damage) {
    if (!indestructable_damage_per_bonus_life) return;
    DEBUG("Charging: %d + %d / %d",
      damage, charge, indestructable_damage_per_bonus_life);

    uint bonus = 0;
    charge += damage;
    while (charge >= indestructable_damage_per_bonus_life) {
      charge -= indestructable_damage_per_bonus_life;
      ++bonus;
      DEBUG("Generating lives: %d -> %d", charge, bonus);
    }
    if (bonus) AdjustLives(bonus, true);
  }

  // Master function for adjusting the number of stored lives. Adjusts the lives
  // count, emits a netevent, and schedules a lives quantity display.
  // The netevent will only be emitted if the quantity of lives changed.
  // If apply_maximum is set, lives will not be granted if this would take you
  // above the configured maximum, but it will not take away lives you already
  // have.
  void AdjustLives(int delta, bool apply_maximum) {
    if (lives < 0) {
      ReportLivesCount();
      return;
    }

    let old_lives = lives;

    if (!apply_maximum || !indestructable_max_lives) {
      lives = max(0, lives + delta);
    } else if (lives < indestructable_max_lives) {
      lives = max(0, min(lives + delta, indestructable_max_lives));
    }

    ReportLivesCount();
  }

  // Called after any AdjustLives call, this schedules a message to the player
  // and netevent reporting how many lives the player has and how much they've
  // changed.
  void ReportLivesCount() {
    force.SetStateLabel("DisplayLivesCount");
  }

  // Display a helpful message indicating how many lives the player has.
  void DisplayLivesCount() {
    let delta = lives - lives_reported;
    if (lives_reported < 0 && lives >= 0) {
      delta = -9999; // going from infinite to finite lives is a reduction
    } else if (lives_reported >= 0 && lives < 0) {
      delta = 9999; // going from finite to infinite is an increase
    }

    EventHandler.SendNetworkEvent("indestructable-report-lives", lives, delta, 0);
    if (lives < 0) {
      Message("$TFIS_MSG_UNLIMITED_LIVES");
    } else if (delta < 0) {
      Message(string.format(StringTable.Localize("$TFIS_MSG_REDUCED_LIVES"), lives));
    } else if (delta > 0) {
      let cv = CVar.GetCVar("indestructable_lifegain_flash_rgb", force.owner.player);
      uint colour = cv ? cv.GetInt() : 0;
      if (colour) {
        colour |= 0xFE000000;
        force.owner.A_SetBlend(colour, 0.8, 40);
      }
      Message(string.format(StringTable.Localize("$TFIS_MSG_INCREASED_LIVES"), lives));
    } else {
      Message(string.format(StringTable.Localize("$TFIS_MSG_UNCHANGED_LIVES"), lives));
    }
    lives_reported = lives;
  }

}

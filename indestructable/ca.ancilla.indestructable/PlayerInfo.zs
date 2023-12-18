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
  int delta_since_report;
  Array<string> levels_cleared;
  ::IndestructableForce force;

  static ::PlayerInfo Create() {
    ::PlayerInfo info = new("::PlayerInfo");
    info.lives = indestructable_starting_lives;
    info.delta_since_report = info.lives;
    return info;
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
    if (LevelSeen(md5)) return;
    let bonus_count = BonusCount();
    if (!bonus_count) return;

    levels_cleared.push(md5);
    let max_lives = indestructable_max_lives_per_level;
    AdjustLives(
      indestructable_lives_per_level * bonus_count,
      indestructable_min_lives_per_level,
      // If life capping is disabled, pass -1 for "no maximum"
      max_lives ? max_lives : -1);
  }

  // Called when a boss is killed.
  void AddBossKillLives() {
    let max_lives = indestructable_max_lives_per_boss;
    AdjustLives(
      indestructable_lives_per_boss,
      indestructable_min_lives_per_boss,
      // If life capping is disabled, pass -1 for "no maximum"
      max_lives ? max_lives : -1);
  }

  // Master function for adjusting the number of stored lives. Properly handles
  // infinities, and adjusts delta_since_report accordingly.
  void AdjustLives(int delta, int min_lives, int max_lives) {
    let old_lives = lives;
    if (lives >= 0) {
      lives += delta;
    }
    if (min_lives != -1) lives = max(lives, min_lives);
    if (max_lives != -1) lives = min(lives, max_lives);

    if (old_lives < 0 && lives >= 0) {
      delta_since_report = -9999; // going from infinite to finite lives is a reduction
    } else if (old_lives >= 0 && lives < 0) {
      delta_since_report = 9999; // going from finite to infinite is an increase
    } else {
      delta_since_report += (lives - old_lives); // for everything else use the actual delta
    }
    ReportLivesCount(lives - old_lives);
  }

  // Called after any AdjustLives call, this displays a message to the player
  // and emits a netevent showing how many lives the player has.
  // Note that this may be called even if the number of lives has not changed.
  void ReportLivesCount(int delta) {
    // Display the message unconditionally, so the player gets reminders as they
    // clear levels and kill bosses even if the lives count didn't change.
    // We do this by setting a state on the force because that delays the message
    // slightly.
    force.SetStateLabel("DisplayLivesCount");
    EventHandler.SendNetworkEvent("indestructable_report_lives", lives, delta, 0);
  }

  // Display a helpful message indicating how many lives the player has.
  void DisplayLivesCount() {
    if (lives < 0) {
      Message("$TFIS_MSG_UNLIMITED_LIVES");
    } else if (delta_since_report < 0) {
      Message(string.format(StringTable.Localize("$TFIS_MSG_REDUCED_LIVES"), lives));
    } else if (delta_since_report > 0) {
      Message(string.format(StringTable.Localize("$TFIS_MSG_INCREASED_LIVES"), lives));
    } else {
      Message(string.format(StringTable.Localize("$TFIS_MSG_UNCHANGED_LIVES"), lives));
    }
    delta_since_report = 0;
  }

}

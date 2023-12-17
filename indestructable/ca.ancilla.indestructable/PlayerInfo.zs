#namespace TFIS;
#debug off;

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

  // Called when starting a new level.
  void AddLevelStartLives() {
    let max_lives = indestructable_max_lives_per_level;
    AdjustLives(
      indestructable_lives_per_level,
      indestructable_min_lives_per_level,
      // If life capping is disabled, pass -1 for "no maximum"
      max_lives ? max_lives : -1);
  }

  // Called when clearing a level. md5 is the md5 checksum of the level, used
  // to ensure we don't award lives for clearing the same level twice.
  void AddLevelClearLives(string md5) {
    if (LevelSeen(md5)) return;
    levels_cleared.push(md5);
    let max_lives = indestructable_max_lives_per_level;
    AdjustLives(
      indestructable_lives_per_level,
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

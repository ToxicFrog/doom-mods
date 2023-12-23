// Intermod service interface for Indestructable.
// The first string argument to a service call is always the name of the function
// to invoke, and the int argument is the index of the player to affect. Other
// arguments depend on the invoked function. The float argument is often used as
// a second int.
//
// Supported functions are:
//
//    GetInt("get-lives", "", int playernum) -> lives
// Returns the number of lives the given player has.
//
//    GetInt("set-lives", "", int playernum, double lives) -> lives
// Sets the player's life count to lives, without respecting upper or lower bounds.
// Setting the count to -1 gives the player infinite lives. Returns the new life
// count.
//
//    GetInt("adjust-lives", str respect_max, int playernum, float delta) -> lives
// Adjusts the number of lives the player has by the delta, which can be negative.
// If respect_max is any value other than "", it will not increase the player's
// life count above the maximum configured in indestructable_max_lives (but it
// will not take away lives that the player already has in excess of that limit
// either). Returns the new life count.
//
//    GetInt("apply-max", "", int playernum, double max) -> lives
// If the player has more than max lives, sets their life count to max. Returns
// the new life count. Max must be >= 0.
//
//    GetInt("apply-min", "", int playernum, double min) -> lives
// If the player has less than min lives, sets their life count to min. Returns
// the new life count. Min must be >= 0.

#namespace TFIS;
#debug off;

class ::IndestructableService : Service play {
  ::IndestructableEventHandler handler;

  void Init(::IndestructableEventHandler handler) {
    self.handler = handler;
  }

  override int GetInt(String fn, String str_arg, int p, double limit, Object _ = null) {
    if (fn == "get-lives") {
      return GetLives(p);
    } else if (fn == "set-lives") {
      return SetLives(p, int(limit));
    } else if (fn == "adjust-lives") {
      return AdjustLives(p, int(limit), str_arg != "");
    } else if (fn == "apply-min") {
      return ApplyMin(p, int(limit));
    } else if (fn == "apply-max") {
      return ApplyMax(p, int(limit));
    } else {
      console.printf("IndestructableService: unknown rpc name '%s'", fn);
      return 0;
    }
  }

  int GetLives(int p) {
    return handler.info[p].lives;
  }

  int SetLives(int p, int lives) {
    handler.info[p].lives = lives;
    return AdjustLives(p, 0, false); // Triggers a lifetotal report
  }

  int AdjustLives(int p, int delta, bool respect_max) {
    handler.info[p].AdjustLives(delta, respect_max);
    return GetLives(p);
  }

  int ApplyMin(int p, int min) {
    let lives = GetLives(p);
    if (lives != -1 && lives < min) {
      return SetLives(p, min);
    }
    return lives;
  }

  int ApplyMax(int p, int max) {
    let lives = GetLives(p);
    if (lives == -1 || lives > max) {
      return SetLives(p, max);
    }
    return lives;
  }
}

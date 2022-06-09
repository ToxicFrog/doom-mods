// An inventory object that can't be dropped and you can only have one of.
// Name comes from Crossfire's force objects used to track spell effects and
// the like.
class TFLV_Force : Inventory {
  Default {
    Inventory.Amount 1;
    Inventory.MaxAmount 1;
    +Inventory.IgnoreSkill;
    +Inventory.Untossable;
  }
}

// Matches the rarity levels in Legendoom.
enum TFLV_LD_Rarity {
  RARITY_COMMON, RARITY_UNCOMMON, RARITY_RARE, RARITY_EPIC
}


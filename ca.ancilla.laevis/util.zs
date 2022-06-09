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

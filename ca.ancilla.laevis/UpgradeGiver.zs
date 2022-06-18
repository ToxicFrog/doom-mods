// A pseudoitem for giving effects to players and letting them make choices from
// a menu in the process.
// This does very little on its own, but has subclasses specialized for various
// tasks. It exists mostly so that currentEffectGiver in the PerPlayerStats
// passes typechecking.
// Subclasses need to implement:
// - a state that repeatedly calls AwaitChoice(menu) until it succeeds (at which
//   point it will jump to the AwaitChoice state)
// - a Chosen state that will be jumped to once a choice is made
#namespace TFLV;

class ::UpgradeGiver : Inventory {
  int chosen;

  Default {
    +Inventory.IgnoreSkill;
    +Inventory.Untossable;
  }

  override bool HandlePickup(Inventory item) {
    // Does not stack, ever.
    return false;
  }

  void AwaitChoice(string menuname) {
    let stats = ::PerPlayerStats.GetStatsFor(owner);
    if (stats.currentEffectGiver) {
      // Someone else using the menu system.
      return;
    }

    stats.currentEffectGiver = self;
    Menu.SetMenu(menuname);
    self.SetStateLabel("AwaitChoice");
  }

  void Choose(int index) {
    let stats = ::PerPlayerStats.GetStatsFor(owner);
    stats.currentEffectGiver = null;
    chosen = index;
    self.SetStateLabel("Chosen");
  }

  States {
    AwaitChoice:
      TNT1 A 1;
      LOOP;
  }
}

class TFLV_LegenDoom_EventHandler : EventHandler
{
  override void OnRegister()
  {
    console.printf("LVLD event handler initialized.");
  }

  override void WorldThingSpawned(WorldEvent evt)
  {
    if (!evt.thing || !evt.thing.GetClassName()) {
      return;
    }
    string name = evt.thing.GetClassName();
    if (evt.thing is "LDWeapon") {
      // TODO: when a new weapon is spawned, set its XP
      console.printf("New LDWeapon: %s", name);
      return;
    }
    if (name.IndexOf("LD") != 0 || name.IndexOf("PickupDroppedLegendary") < 0) {
      return;
    }
    console.printf("Found legendoom dropped legendary weapon: %s", name);
  }
}


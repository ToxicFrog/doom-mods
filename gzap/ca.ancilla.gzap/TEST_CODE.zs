class GZAP_DataPackageEventHandler : StaticEventHandler {
  override void OnRegister() {
    let peh = GZAP_PlayEventHandler.Get();

    // TEST CODE DO NOT EAT
    // MAP01 - Entryway
    peh.RegisterSkill(2);
    peh.RegisterMap("MAP01");
    peh.RegisterCheck("MAP01", 1, "MAP01 - GreenArmor", false, (592.0, 2624.0, 48.0), 270.0);
    peh.RegisterCheck("MAP01", 2, "MAP01 - RocketLauncher", false, (832.0, 1600.0, 56.0), 270.0);
    peh.RegisterCheck("MAP01", 3, "MAP01 - Shotgun", true, (320.0, 368.0, -32.0), 0.0);
    peh.RegisterMap("MAP02");
    peh.RegisterKey("MAP02", "BlueCard");
    peh.RegisterKey("MAP02", "RedCard");
    // TODO: data package should also register keyset for each map, which handler
    // can then install in the keyrings as they are initialized

  }
}

class GZAP_DataPackageEventHandler : StaticEventHandler {
  override void OnRegister() {
    console.printf("Data package installing...");
    let peh = GZAP_PlayEventHandler.Get();

    // TEST CODE DO NOT EAT
    // MAP01 - Entryway
    peh.RegisterSkill(2);
    peh.RegisterMap("MAP01", 1, 2, 3);
    peh.RegisterCheck("MAP01", 1, "MAP01 - GreenArmor", false, (592.0, 2624.0, 48.0), 270.0);
    peh.RegisterCheck("MAP01", 2, "MAP01 - RocketLauncher", false, (832.0, 1600.0, 56.0), 270.0);
    peh.RegisterCheck("MAP01", 3, "MAP01 - Shotgun", true, (320.0, 368.0, -32.0), 0.0);
    peh.RegisterMap("MAP02", 4, 5, 6);
    peh.RegisterItem("RocketLauncher", 7);
    // TODO: data package should also register keyset for each map, which handler
    // can then install in the keyrings as they are initialized
    // TODO: data package needs to register the item ID index, which is probably
    // going to be multiple maps, because each ID can be either:
    // - an in-game item, identified by its typename;
    // - a level-scoped key, identified by its typename and level;
    // - an automap, identified by its level; or
    // - a level access token, identified by its level.
    // RegisterMap(string mapname, int access_apid, int automap_apid)
    // RegisterKey(string mapname, string typename, int apid)
    // RegisterItem(string typename, int apid)
    console.printf("Archipelago data package installed.");
  }
}

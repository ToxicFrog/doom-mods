// Event handler for Laevis.
// Handles giving players a stat tracking item when they spawn in, and assigning
// XP to their currently wielded weapon when they damage something.

class TFLV_EventHandler : StaticEventHandler
{
  override void OnRegister()
  {
    console.printf("LVLD event handler initialized.");
  }

  bool IsInterestingEvent(WorldEvent evt) {
    return
      // We need a target and a source
      evt.thing
      && evt.damageSource
      // Don't count self-damage
      && evt.thing != evt.damageSource
      // Did at least 1 point of damage
      && evt.damage > 0
      // Target needs to be a monster, not a barrel or something
      && evt.thing.bISMONSTER
      // Source needs to be a player
      && PlayerPawn(evt.damageSource);
  }

  TFLV_PerPlayerStats GetStatHolderFor(PlayerPawn pawn) {
    let stats = TFLV_PerPlayerStats(pawn.FindInventory("TFLV_PerPlayerStats"));
    if (!stats) {
      return TFLV_PerPlayerStats(pawn.GiveInventoryType("TFLV_PerPlayerStats"));
    }
    return stats;
  }

  // TODO: we need to move this to ModifyDamage() so we can get the before-
  // bonuses damage and assign XP based on that. Otherwise the damage bonus means
  // that the XP per level gradually converges on (XP_PER_LEVEL * 16.6).
  override void WorldThingDamaged(WorldEvent evt)
  {
    if (!IsInterestingEvent(evt)) {
      return;
    }

    // DamageSource is the ultimate source of the damage, i.e. the player who
    // fired the rocket launcher, as opposed to the rocket launcher itself, the
    // rocket, or the explosion it spawned on hit.
    let source = PlayerPawn(evt.damageSource);
    let gun = Weapon(source.player.readyWeapon);
    if (!gun) {
      console.printf("Player did %d damage without a weapon, somehow", evt.damage);
    }

    int damage = evt.damage;
    if (evt.thing.health < 0) {
      damage = damage + evt.thing.health; // Don't give credit for overkill
      // TODO: scale XP nonlinearly with target max health, so doing 10 damage
      // to a Cyberdemon is worth more XP than doing 10 damage to a former.
      // For reference, formers have 20hp, archviles have 700, barons have 1000,
      // Cyberdemon has 4000 and Mastermind has 3000.
    }
    TFLV_PerPlayerStats stats = GetStatHolderFor(source);
    stats.AddXPTo(gun, damage);
    stats.PrintXPFor(gun);
  }

  override void PlayerSpawned(PlayerEvent evt) {
    PlayerPawn pawn = players[evt.playerNumber].mo;
    if (pawn) {
      pawn.GiveInventoryType("TFLV_PerPlayerStats");
    }
  }
}


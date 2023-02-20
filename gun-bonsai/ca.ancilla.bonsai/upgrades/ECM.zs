#namespace TFLV::Upgrade;
#debug off;

class ::ECM : ::BaseUpgrade {
  override bool IsSuitableForPlayer(TFLV::PerPlayerStats info) {
    return true;
  }

  // Range at which we try to hack incoming missiles.
  uint EcmRange(uint level) {
    return 192 + level*64; // 6m + 2m/level
  }

  // Range within which we search for enemies to redirect against.
  uint LockRange(uint level) {
    return 128 + level*32; // 4m + 1m/level
  }

  // Chance, per shot, that if we couldn't redirect a missile we are unable to
  // reprogram it to home in on its launcher instead.
  float UnhackableChance(uint level) {
    // 20%/level with diminishing returns.
    return 0.8 ** level;
  }

  override void Tick(Actor owner) {
    let radius = EcmRange(self.level);
    ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
    Actor shot;
    Array<Actor> monsters; bool did_monsters = false;
    while (shot = Actor(it.next())) {
      if (!shot || !shot.bSEEKERMISSILE || shot.tracer != owner || shot.bINCOMBAT || owner.Distance3D(shot) > radius) {
        // DEBUG("Skipping %s", TAG(shot));
        continue;
      }
      DEBUG("Found shot %s with tracer=%s target=%s",
        TAG(shot), TAG(shot.tracer), TAG(shot.target));
      // Found a seeker missile aimed at the player.
      // First, try to redirect it against a nearby enemy.
      if (!did_monsters) {
        TFLV::Util.MonstersInRadius(owner, LockRange(self.level), monsters);
        did_monsters = true;
      }
      if (monsters.size()) {
        // If we found a nearby monster to judo it into, do so.
        shot.tracer = monsters[random(0, monsters.size()-1)];
        shot.target = owner;
      } else if (frandom(0.0, 1.0) >= UnhackableChance(self.level)) {
        // Else we have a chance to reprogram it to hunt its creator.
        shot.tracer = shot.target;
        shot.target = owner;
      } else {
        // We set the +INCOMBAT flag to keep track of shots we've already tried
        // and failed to redirect.
        // This shouldn't break anything since this flag is normally used to control
        // Strife dialogue and homing missiles are not known for being particularly
        // conversational.
        shot.bINCOMBAT = true;
      }
    }
  }

  override void GetTooltipFields(Dictionary fields, uint level) {
    fields.insert("ecm-range", AsMeters(EcmRange(level)));
    fields.insert("lock-range", AsMeters(LockRange(level)));
    fields.insert("ecm-chance", AsPercent(1.0 - UnhackableChance(level)));
  }
}


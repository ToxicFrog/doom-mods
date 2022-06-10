

/*
class LVLDEffectRemoverLib
{
  static void CopyLegendaryEffects(string prefix)
  {
    for (int i = 0; i < AllActorClasses.Size(); ++i) {
      let cls = AllActorClasses[i];
      let name = cls.GetClassName();
      if (name.IndexOf(prefix) == 0 && CountInv(cls) > 0) {
        print(s:"Found effect in player inventory: ", s:name);
      } else {
        print(s:"Missing: ", s:name);
      }
    }
  }
}


class LVLDPistolEffectRemover : LDPistolEffectRemover replaces LDPistolEffectRemover
{
  States {
    Pickup:
      TNT1 A 0 { LVLDEffectRemoverLib.CopyLegendaryEffects("LDPistolEffect_"); }
      goto super::Pickup;
  }
}
*/


// A pseudoitem that, when given to the player, attempts to give them a Legendoom
// upgrade appropriate to the weapon described by 'wielded'.
// This works by repeatedly spawning the appropriate Legendoom random pickup until
// it generates in a way we can use, then either shoving it into the player directly
// or copying some of the info out of it.

class TFLV_LegendoomEffectCycler : TFLV_Force {
  TFLV_WeaponInfo info;
  string prefix;

  // We use States here and not just a simple method because we need to be able
  // to insert delays to let LD item generation code do its things at various
  // times.
  States {
    CycleEffect:
      TNT1 A 1 CycleEffect();
      STOP;
      // TODO: This *should* spawn the Legendoom splash screen the first time you
      // switch to a new effect, but it doesn't seem to. Probably I need to do
      // something so it interacts properly with the "has the user seen this
      // splash already" check, which I do not understand. For now, this code is
      // disabled.
      TNT1 A 0 A_SpawnItemEx ("LDPistolLegendaryEffectHax", 0,0,0, 0,0,0, 0, SXF_NOCHECKPOSITION | SXF_SETMASTER);
      "####" "#" 0 ACS_NamedExecuteAlways("LDWeaponPickupEffectActivation", 0);
      STOP;
  }

  void CycleEffect() {
    if (info.effects.size() <= 1) return;
    owner.TakeInventory(info.effects[info.currentEffect], 1);
    info.NextEffect();
    owner.GiveInventory(info.effects[info.currentEffect], 1);
  }
}

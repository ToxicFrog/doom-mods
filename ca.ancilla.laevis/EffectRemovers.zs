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

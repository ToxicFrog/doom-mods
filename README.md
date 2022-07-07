# ToxicFrog's Doom Mods

This repo contains some Doom mods. These are all ZScript-based and thus require a recent (4.x) release of [gzDoom](https://zdoom.org/downloads); they will not work on other ports.

Downloadable versions can be found on the [releases page](https://github.com/ToxicFrog/laevis/releases); the latest release will always contain the latest version of each mod, even if they weren't updated in that release. Note that even if you only want one of the mods **you must also download and load libntear**, as it contains code they depend on.

## Included Mods

- [libntear](libntear/), a utility library. This does nothing on its own (and is safe to leave in your load order), but is absolutely required for the other mods in this repo to function. In particular, it contains the code that adds support for tooltips on the options menu, along with some compatibility shims to make interoperability between the other mods easier.
- [Laevis](laevis/), a mod of growing your guns from small shrubs into beautiful murder trees. Earn XP for your weapons by killing hellspawn and customize them with randomized upgrades. Compatible with almost every IWAD and mod.
- [Indestructable](indestructable/), a minimod that gives you a second chance on death, inspired by (War of Attrition's)[https://fissile.duke4.net/fissile_attrition.html] "Death Rage" mechanic.

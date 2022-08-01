NAME=GunBonsai
VERSION=0.8.2
LUMPS=zscript.txt MAPINFO CVARINFO SNDINFO KEYCONF MENUDEF LANGUAGE.* sprites sounds
LUMPS+=*.md COPYING.freedoom
ZSDIR=ca.ancilla.bonsai

include ${TOPDIR}/rules.make

sprites:
	$(MAKE) -C sprites/ui

clean: clean.super
	$(MAKE) -C sprites/ui/ clean

.PHONY: clean sprites

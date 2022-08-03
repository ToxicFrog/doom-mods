NAME=GunBonsai
VERSION=0.8.3
LUMPS=zscript.txt MAPINFO CVARINFO SNDINFO KEYCONF MENUDEF GLDEFS LANGUAGE.* sprites sounds
LUMPS+=*.md COPYING.freedoom
ZSDIR=ca.ancilla.bonsai

include ${TOPDIR}/rules.make

sprites:
	$(MAKE) -C sprites/ui

clean: clean.super
	$(MAKE) -C sprites/ui/ clean

.PHONY: clean sprites

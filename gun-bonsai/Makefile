NAME=GunBonsai
VERSION=0.8.6
LUMPS=zscript.txt LANGUAGE.* sprites sounds *.md COPYING.freedoom
LUMPS+=MAPINFO CVARINFO SNDINFO KEYCONF MENUDEF GLDEFS
ZSDIR=ca.ancilla.bonsai

include ${TOPDIR}/rules.make

sprites:
	$(MAKE) -C sprites/ui

clean: clean.super
	$(MAKE) -C sprites/ui/ clean

.PHONY: clean sprites

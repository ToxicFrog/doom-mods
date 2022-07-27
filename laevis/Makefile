NAME=Laevis
VERSION=0.7.5
LUMPS=zscript.txt MAPINFO CVARINFO KEYCONF MENUDEF LANGUAGE.* sprites
LUMPS+=*.md COPYING.freedoom
ZSDIR=ca.ancilla.laevis

include ${TOPDIR}/rules.make

sprites:
	$(MAKE) -C sprites/ui

clean: clean.super
	$(MAKE) -C sprites/ui/ clean

.PHONY: clean sprites

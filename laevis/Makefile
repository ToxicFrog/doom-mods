NAME=Laevis
VERSION=0.7.2
LUMPS=zscript.txt MAPINFO CVARINFO KEYCONF MENUDEF LANGUAGE.* sprites
LUMPS+=*.md COPYING.freedoom
ZSDIR=ca.ancilla.laevis

include ${TOPDIR}/rules.make

sprites: sprites/ui/hud.xcf
	$(MAKE) -C sprites/ui/
	touch sprites

clean: clean.super
	$(MAKE) -C sprites/ui/ clean

.PHONY: clean

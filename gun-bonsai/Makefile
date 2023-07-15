NAME=GunBonsai
VERSION=0.10.3
LUMPS=zscript.txt LANGUAGE.* *.md COPYING.freedoom
LUMPS+=MAPINFO CVARINFO SNDINFO KEYCONF MENUDEF GLDEFS BONSAIRC
LUMPS+=sprites sounds textures
ZSDIR=ca.ancilla.bonsai
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
LIBTTM_PREFIX=TFLV

include ${TOPDIR}/rules.make

sprites:
	$(MAKE) -C sprites/ui

clean: clean.super
	$(MAKE) -C sprites/ui/ clean

.PHONY: clean sprites

NAME=GunBonsai
VERSION=0.11.0
LUMPS=zscript.txt LANGUAGE.* *.md COPYING.freedoom
LUMPS+=MAPINFO CVARINFO SNDINFO KEYCONF MENUDEF GLDEFS BONSAIRC
LUMPS+=sprites sounds textures
ZSDIR=ca.ancilla.bonsai
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
LIBTTM_PREFIX=TFLV

include ${TOPDIR}/rules.make

sprites: FORCE
	$(MAKE) -C sprites/ui
	if find sprites -type f -newer sprites | egrep -q .; then touch sprites; fi

clean: clean.super
	$(MAKE) -C sprites/ui/ clean

.PHONY: clean
FORCE:

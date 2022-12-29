NAME=GunBonsai
VERSION=0.9.7
LUMPS=zscript.txt LANGUAGE.* *.md COPYING.freedoom
LUMPS+=MAPINFO CVARINFO SNDINFO KEYCONF MENUDEF GLDEFS BONSAIRC
LUMPS+=sprites sounds textures
ZSDIR=ca.ancilla.bonsai
ZSCRIPT=ca.ancilla.bonsai/libtooltipmenu/TooltipOptionMenu.zsc ca.ancilla.bonsai/libtooltipmenu/Tooltips.zsc

include ${TOPDIR}/rules.make

ca.ancilla.bonsai/libtooltipmenu/%:
	sed -E 's,TF_,TFLV_,g; s,ItemTooltip,ItemTFLV_Tooltip,g' ${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu/$* > $@

sprites:
	$(MAKE) -C sprites/ui

clean: clean.super
	$(MAKE) -C sprites/ui/ clean
	rm -rf ${ZSCRIPT}

.PHONY: clean sprites

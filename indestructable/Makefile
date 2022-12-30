NAME=Indestructable
VERSION=0.2.5
LUMPS=CVARINFO MAPINFO MENUDEF zscript.txt
LUMPS+=*.md textures
ZSDIR=ca.ancilla.indestructable
ZSCRIPT=${ZSDIR}/libtooltipmenu/TooltipOptionMenu.zsc ${ZSDIR}/libtooltipmenu/Tooltips.zsc
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu

include ${TOPDIR}/rules.make

${ZSDIR}/libtooltipmenu/%:
	sed -E 's,TF_,TFIS_,g; s,ItemTooltip,ItemTFIS_Tooltip,g' ${LIBTTM}/$* > $@

clean: clean.super
	rm -rf ${ZSCRIPT}

.PHONY: clean

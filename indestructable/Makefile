NAME=Indestructable
VERSION=0.1.0
LUMPS=CVARINFO MAPINFO MENUDEF zscript.txt
LUMPS+=*.md
ZSDIR=ca.ancilla.indestructable

include ${TOPDIR}/rules.make

MENUDEF: MENUDEF.in
	sed -E 's,TFLV_,TFLV_IN_,g; s, Tooltip, ISTooltip,g' $^ > $@

clean: clean.super
	rm -f MENUDEF

.PHONY: clean

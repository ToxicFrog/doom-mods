NAME=Indestructable
LUMPS=CVARINFO MAPINFO MENUDEF README.md zscript.txt
ZSDIR=ca.ancilla.indestructable

include ${TOPDIR}/rules.make

MENUDEF: MENUDEF.in
	sed -E 's,TFLV_,TFLV_IN_,g; s, Tooltip, ISTooltip,g' $^ > $@

clean: clean.super
	rm -f MENUDEF

.PHONY: clean

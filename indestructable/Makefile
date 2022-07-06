PK3=../release/Indestructable-${VERSION}.pk3
LUMPS=CVARINFO MAPINFO MENUDEF README.md zscript.txt
ZSCRIPT=ca.ancilla.indestructable/Indestructable.zsc ca.ancilla.indestructable/TooltipOptionMenu.zsc

all: ${PK3}

${PK3}: ${LUMPS} ${ZSCRIPT}
	rm -f $@
	zip -qr $@ $^

ca.ancilla.indestructable/TooltipOptionMenu.zsc: ../ca.ancilla.laevis/menu/TooltipOptionMenu.zsc
	sed -E 's,TFLV_,TFLV_IN_,g; s,OptionMenuItemTooltip,OptionMenuItemISTooltip,g' $^ > $@

MENUDEF: MENUDEF.in
	sed -E 's,TFLV_,TFLV_IN_,g; s, Tooltip, ISTooltip,g' $^ > $@

clean:
	rm -f ${PK3} MENUDEF ca.ancilla.indestructable/TooltipOptionMenu.zsc

.PHONY: all clean

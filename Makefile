VERSION="0.6.3"
PK3=release/Laevis-${VERSION}.pk3
LUMPS=zscript.txt MAPINFO CVARINFO KEYCONF MENUDEF LANGUAGE.*
SPRITES=sprites/
ZSCRIPT=$(patsubst %.zs,%.zsc,$(shell find ca.ancilla.laevis -name "*.zs"))

all: ${PK3}

${PK3}: README.md COPYING.md ${LUMPS} ${SPRITES} ${ZSCRIPT} sprites/ui/LHUDA2.png
	rm -f $@
	zip -qr $@ README.md COPYING.md ${LUMPS} sprites/ ca.ancilla.laevis/

%.zsc: %.zs zspp
	./zspp $< $@

# Quick hack to make it rebuild the HUD sprites when the XCF changes.
sprites/ui/LHUDA2.png: sprites/ui/hud.xcf
	$(MAKE) -C sprites/ui/

clean:
	find ca.ancilla.laevis -name '*.zsc' -delete
	$(MAKE) -C sprites/ui/ clean

deploy: ${PK3}
	ln -sf ${PK3} Laevis.pk3

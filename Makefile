VERSION="0.2alpha8"
PK3=Laevis-${VERSION}.pk3
LUMPS=MAPINFO CVARINFO KEYCONF MENUDEF LANGUAGE.*
ZSCRIPT=$(patsubst %.zs,%.zsc,$(shell find . -name "*.zs"))

all: ${PK3}

${PK3}: README.md COPYING.md ${LUMPS} zscript.txt ${ZSCRIPT}
	rm -f $@
	zip -r $@ $^

%.zsc: %.zs zspp
	./zspp $< $@

clean:
	rm -f Laevis*.pk3

deploy: ${PK3}
	ln -sf ${PK3} Laevis.pk3
	cp ${PK3} /ancilla/installs/games/PC/DOOM/
	ln -sf ./${PK3} /ancilla/installs/games/PC/DOOM/Laevis.pk3

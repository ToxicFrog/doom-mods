VERSION="0.6.0"
PK3=release/Laevis-${VERSION}.pk3
LUMPS=MAPINFO CVARINFO KEYCONF MENUDEF LANGUAGE.* sprites/
ZSCRIPT=$(patsubst %.zs,%.zsc,$(shell find . -name "*.zs"))

all: ${PK3}

${PK3}: README.md COPYING.md ${LUMPS} zscript.txt ${ZSCRIPT}
	rm -f $@
	zip -r $@ $^

%.zsc: %.zs zspp
	./zspp $< $@

clean:
	find . -name '*.zsc' -delete

deploy: ${PK3}
	ln -sf ${PK3} Laevis.pk3

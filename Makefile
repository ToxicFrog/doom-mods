VERSION="0.1alpha1"
PK3=Laevis-${VERSION}.pk3

all: ${PK3}

${PK3}: README.md COPYING.md MAPINFO CVARINFO KEYCONF MENUDEF zscript.txt ca.ancilla.laevis/*.zs
	rm -f $@
	zip -r $@ $^

clean:
	rm -f Laevis*.pk3

deploy: ${PK3}
	cp ${PK3} /ancilla/installs/games/PC/DOOM/

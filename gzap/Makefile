NAME=gzArchipelago
TAGS=gzap-*
VERSION=0.6.5
LUMPS=MAPINFO MENUDEF zscript.txt *.md LANGUAGE.csv CVARINFO KEYCONF TEXTURES.txt
LUMPS+=sprites textures maps patches config
ZSDIR=ca.ancilla.gzap
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
LIBTTM_PREFIX=GZAP

all: ${PK3} apworld

include ${TOPDIR}/rules.make

apworld: version ${TOPDIR}/release/gzdoom.apworld ${TOPDIR}/release/ap_gzdoom_featured.apworld ${TOPDIR}/release/ap_gzdoom_extras.apworld
${PK3}: sprites/icons

version:
	${TOPDIR}/tools/version-stamp "${TAGS}" apworld/gzdoom/VERSION

ca.ancilla.gzap/PlayEventHandler.zsc: apworld/gzdoom/VERSION

sprites/icons: apworld/gzdoom/icons/__init__.py assets/*.png
	rm -f sprites/icons/*.png
	python apworld/gzdoom/icons/__init__.py
	touch sprites/icons

${TOPDIR}/release/%.apworld: apworld/%/* apworld/%/*/*
	cd apworld && zip -r $*.apworld $*
	cp apworld/$*.apworld ~/.local/share/Archipelago/worlds/
	cp apworld/$*.apworld ${TOPDIR}/release/
	mv apworld/$*.apworld ${TOPDIR}/release/$*-${VERSION}.apworld

.PHONY: apworld

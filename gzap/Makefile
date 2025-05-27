NAME=gzArchipelago
TAGS=gzap-*
VERSION=0.6.0
LUMPS=MAPINFO MENUDEF zscript.txt *.md LANGUAGE.csv CVARINFO KEYCONF
LUMPS+=sprites textures maps GZAPRC
ZSDIR=ca.ancilla.gzap
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
LIBTTM_PREFIX=GZAP

all: ${PK3} apworld

include ${TOPDIR}/rules.make

apworld: version ${TOPDIR}/release/gzdoom-${VERSION}.apworld
${PK3}: sprites/icons/.built

version:
	${TOPDIR}/tools/version-stamp "${TAGS}" apworld/gzdoom/VERSION

ca.ancilla.gzap/PlayEventHandler.zsc: apworld/gzdoom/VERSION

sprites/icons/.built: apworld/gzdoom/icons.py assets/*.png
	rm -rf sprites/icons/
	mkdir -p sprites/icons/
	python apworld/gzdoom/icons.py
	touch sprites/icons/.built

${TOPDIR}/release/gzdoom-${VERSION}.apworld: apworld/gzdoom/* apworld/gzdoom/*/*
	cd apworld && zip -r gzdoom.apworld gzdoom
	cp apworld/gzdoom.apworld ~/.local/share/Archipelago/worlds/
	cp apworld/gzdoom.apworld ${TOPDIR}/release/
	mv apworld/gzdoom.apworld ${TOPDIR}/release/gzdoom-${VERSION}.apworld

.PHONY: apworld

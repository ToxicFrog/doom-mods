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

apworld: version ${TOPDIR}/release/gzdoom-${VERSION}.apworld
${PK3}: sprites/icons

version:
	${TOPDIR}/tools/version-stamp "${TAGS}" apworld/gzdoom/VERSION

ca.ancilla.gzap/PlayEventHandler.zsc: apworld/gzdoom/VERSION

sprites/icons: apworld/gzdoom/icons/__init__.py assets/*.png
	rm -f sprites/icons/*.png
	python apworld/gzdoom/icons/__init__.py
	touch sprites/icons

${TOPDIR}/release/gzdoom-${VERSION}.apworld: apworld/gzdoom/* apworld/gzdoom/*/*
	cd apworld && zip -r gzdoom.apworld gzdoom
	cp apworld/gzdoom.apworld ~/.local/share/Archipelago/worlds/
	cp apworld/gzdoom.apworld ${TOPDIR}/release/
	mv apworld/gzdoom.apworld ${TOPDIR}/release/gzdoom-${VERSION}.apworld

.PHONY: apworld

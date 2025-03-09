NAME=gzArchipelago
VERSION=0.3.1
LUMPS=MAPINFO MENUDEF zscript.txt *.md LANGUAGE.csv CVARINFO
LUMPS+=sprites textures maps
ZSDIR=ca.ancilla.gzap
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
LIBTTM_PREFIX=GZAP

all: ${PK3} apworld

include ${TOPDIR}/rules.make

apworld: ${TOPDIR}/release/gzdoom-${VERSION}.apworld

${TOPDIR}/release/gzdoom-${VERSION}.apworld: apworld/gzdoom/* apworld/gzdoom/*/*
	cd apworld && zip -r gzdoom.apworld gzdoom
	cp apworld/gzdoom.apworld ~/Archipelago/worlds/
	cp apworld/gzdoom.apworld ${TOPDIR}/release/
	mv apworld/gzdoom.apworld ${TOPDIR}/release/gzdoom-${VERSION}.apworld

.PHONY: apworld

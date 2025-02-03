NAME=GZAP
VERSION=0.0.0
#LUMPS=CVARINFO MAPINFO MENUDEF zscript.txt LANGUAGE.*
#LUMPS+=*.md textures
LUMPS=MAPINFO zscript.txt sprites
ZSDIR=ca.ancilla.gzap
# LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
# LIBTTM_PREFIX=GZAP

all: ${PK3} apworld

apworld: ${TOPDIR}/release/gzdoom.apworld

include ${TOPDIR}/rules.make

${TOPDIR}/release/gzdoom.apworld: apworld/* apworld/gzdoom/*
	cd apworld && zip -r gzdoom.apworld gzdoom
	cp apworld/gzdoom.apworld ~/Archipelago/worlds/
	mv apworld/gzdoom.apworld $@

.PHONY: apworld

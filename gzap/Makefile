NAME=GZAP
VERSION=0.0.0
LUMPS=MAPINFO MENUDEF zscript.txt *.md LANGUAGE.csv
LUMPS+=sprites textures maps
ZSDIR=ca.ancilla.gzap
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
LIBTTM_PREFIX=GZAP

all: ${PK3} apworld ipc

include ${TOPDIR}/rules.make

apworld:
	cd apworld && zip -r gzdoom.apworld gzdoom
	cp apworld/gzdoom.apworld ~/Archipelago/worlds/
	mv apworld/gzdoom.apworld ${TOPDIR}/release/

ipc:
	dd if=${TOPDIR}/README.md of=${TOPDIR}/testdata/GZAPIPC bs=1K count=1

.PHONY: apworld ipc

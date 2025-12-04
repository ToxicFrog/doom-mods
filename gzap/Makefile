NAME=gzArchipelago
TAGS=gzap-*
VERSION=0.6.6
LUMPS=MAPINFO MENUDEF zscript.txt *.md LANGUAGE.csv CVARINFO KEYCONF TEXTURES.txt
LUMPS+=sprites textures maps patches config/*
ZSDIR=ca.ancilla.gzap
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
LIBTTM_PREFIX=GZAP
APWORLDS:=${TOPDIR}/release/apworlds

all: version ${PK3} apworlds install

include ${TOPDIR}/rules.make

apworlds: core_apworld addon_apworlds

core_apworld: version ${TOPDIR}/release/gzdoom.apworld
addon_apworlds: $(patsubst wads/%/,${APWORLDS}/zdoom_%.apworld,$(wildcard wads/*/))
${PK3}: sprites/icons

version:
	${TOPDIR}/tools/version-stamp "${TAGS}" apworld/gzdoom/VERSION

ca.ancilla.gzap/PlayEventHandler.zsc: apworld/gzdoom/VERSION

sprites/icons: apworld/gzdoom/icons/__init__.py assets/*.png
	rm -f sprites/icons/*.png
	python apworld/gzdoom/icons/__init__.py
	touch sprites/icons

${TOPDIR}/release/gzdoom.apworld: apworld/gzdoom/* apworld/gzdoom/*/*
	cd apworld && zip -qr gzdoom.apworld gzdoom
	mv apworld/gzdoom.apworld $@

${APWORLDS}/zdoom_%.apworld: apworld/zdoom_%/__init__.py apworld/zdoom_%/archipelago.json
	cd apworld && zip -qr9 zdoom_$*.apworld zdoom_$*/
	mv apworld/zdoom_$*.apworld $@

apworld/zdoom_%/archipelago.json: wads/archipelago.tmpl version apworld/zdoom_%
	sed -E "s,__WAD__,$*," wads/archipelago.tmpl > apworld/zdoom_$*/archipelago.json

apworld/zdoom_%/__init__.py: wads/__init__.tmpl apworld/zdoom_%
	sed -E "s,__WAD__,$*,; s,__VERSION__,`cat apworld/gzdoom/VERSION`," wads/__init__.tmpl > apworld/zdoom_$*/__init__.py

apworld/zdoom_%: wads/$* wads/$*/*
	rm -rf apworld/zdoom_$*/
	cp -a wads/$* apworld/zdoom_$*
	mkdir -p apworld/zdoom_$*/logic apworld/zdoom_$*/tuning
	mv apworld/zdoom_$*/*.logic apworld/zdoom_$*/logic/ || true
	mv apworld/zdoom_$*/*.tuning apworld/zdoom_$*/tuning/ || true

install: core_apworld addon_apworlds
	cp -a ${TOPDIR}/release/gzdoom.apworld ~/.local/share/Archipelago/worlds
	cp -a ${APWORLDS}/*.apworld ~/.local/share/Archipelago/worlds

clean: clean.super
	rm -rf apworld/zdoom_*
	rm -rf ${APWORLDS}/zdoom_*

.PHONY: apworld install
.SECONDARY:

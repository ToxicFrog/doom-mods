NAME=UZArchipelago
TAGS=gzap-*
VERSION=0.8.0
LUMPS=MAPINFO MENUDEF zscript.txt *.md LANGUAGE.csv CVARINFO KEYCONF TEXTURES.txt TEXTCOLO
LUMPS+=sprites textures maps patches config/*
ZSDIR=ca.ancilla.gzap
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
LIBTTM_PREFIX=GZAP
APWORLDS:=${TOPDIR}/release/apworlds

all: version ${PK3} apworlds apworld_generator install

include ${TOPDIR}/rules.make

apworlds: core_apworld addon_apworlds
apworld_generator: ${TOPDIR}/docs/apworld-generator.html

core_apworld: version ${TOPDIR}/release/uzdoom.apworld
addon_apworlds: $(patsubst wads/%/,${APWORLDS}/zdoom_%.apworld,$(wildcard wads/*/))
${PK3}: sprites/icons

version: apworld/uzdoom/VERSION

apworld/uzdoom/VERSION: ${TOPDIR}/.git/refs/heads/main
	${TOPDIR}/tools/version-stamp "${TAGS}" apworld/uzdoom/VERSION

ca.ancilla.gzap/PlayEventHandler.zsc: apworld/uzdoom/VERSION

sprites/icons: apworld/uzdoom/icons/__init__.py assets/*.png
	rm -f sprites/icons/*.png
	python apworld/uzdoom/icons/__init__.py
	touch sprites/icons

${TOPDIR}/release/uzdoom.apworld: apworld/uzdoom/* apworld/uzdoom/*/*
	cd apworld && zip -qr uzdoom.apworld uzdoom
	mv apworld/uzdoom.apworld $@

${APWORLDS}/zdoom_%.apworld: apworld/zdoom_%/
	cd apworld && zip -qr9 zdoom_$*.apworld zdoom_$*/
	mv apworld/zdoom_$*.apworld $@

${TOPDIR}/docs/apworld-generator.html: ${TOPDIR}/docs/apworld-generator.sh wads/__template__/*
	sh $< > $@

# Prepare a directory for conversion into an apworld by copying the template
# files into it, evaluating the templates, and then copying the logic, tuning,
# and customization files into it.
apworld/zdoom_%/: wads/%/* wads/__template__/* version
	rm -rf apworld/zdoom_$*/
	mkdir -p apworld/zdoom_$*
	cp -a wads/__template__/* apworld/zdoom_$*
	sed -E -i "s,__WAD__,$*,g" apworld/zdoom_$*/*
	cp -a apworld/uzdoom/VERSION apworld/zdoom_$*
	cp -a wads/$*/* apworld/zdoom_$*/
	mkdir -p apworld/zdoom_$*/logic apworld/zdoom_$*/tuning
	mv apworld/zdoom_$*/*.logic apworld/zdoom_$*/logic/ || true
	mv apworld/zdoom_$*/*.tuning apworld/zdoom_$*/tuning/ || true

install: core_apworld addon_apworlds ${PK3}
	cp -a ${TOPDIR}/release/uzdoom.apworld ~/.local/share/Archipelago/worlds
	cp -a ${APWORLDS}/*.apworld ~/.local/share/Archipelago/worlds

clean: clean.super
	rm -rf apworld/zdoom_*
	rm -rf ${APWORLDS}/zdoom_*

.PHONY: apworld install ${APWORLDS}/zdoom___template__.apworld
.SECONDARY:

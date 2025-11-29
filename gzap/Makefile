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
addon_apworlds: $(patsubst apworld/addons/%/,${APWORLDS}/zdoom_%.apworld,$(wildcard apworld/addons/*/))
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

${APWORLDS}/zdoom_%.apworld: apworld/zdoom_%/__init__.py
	cd apworld && zip -qr9 zdoom_$*.apworld zdoom_$*/
	mv apworld/zdoom_$*.apworld $@

apworld/zdoom_%/__init__.py: apworld/addons/*.tmpl apworld/addons/%/* version
	mkdir -p apworld/zdoom_$*/logic apworld/zdoom_$*/tuning
	cp apworld/addons/$*/* apworld/zdoom_$*/logic/
	mv apworld/zdoom_$*/logic/*.tuning apworld/zdoom_$*/tuning/ || true
	sed -E "s,__WAD__,$*," apworld/addons/archipelago.tmpl > apworld/zdoom_$*/archipelago.json
	sed -E "s,__WAD__,$*,; s,__VERSION__,`cat apworld/gzdoom/VERSION`," apworld/addons/__init__.tmpl > apworld/zdoom_$*/__init__.py

install: core_apworld addon_apworlds
	cp -a ${TOPDIR}/release/gzdoom.apworld ~/.local/share/Archipelago/worlds
	cp -a ${APWORLDS}/*.apworld ~/.local/share/Archipelago/worlds

.PHONY: apworld install
.SECONDARY:

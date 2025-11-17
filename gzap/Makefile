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
addon_apworlds: $(patsubst apworld/addons/%/,${APWORLDS}/addon_gzdoom_%.apworld,$(wildcard apworld/addons/*/))
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

${APWORLDS}/addon_gzdoom_%.apworld: apworld/addon_gzdoom_%/__init__.py
	cd apworld && zip -qr9 addon_gzdoom_$*.apworld addon_gzdoom_$*/
	mv apworld/addon_gzdoom_$*.apworld $@

apworld/addon_gzdoom_%/__init__.py: apworld/addons/*.tmpl apworld/addons/%/*
	mkdir -p apworld/addon_gzdoom_$*/logic apworld/addon_gzdoom_$*/tuning
	cp apworld/addons/$*/* apworld/addon_gzdoom_$*/logic/
	mv apworld/addon_gzdoom_$*/logic/*.tuning apworld/addon_gzdoom_$*/tuning/ || true
	sed -E "s,__WAD__,$*," apworld/addons/archipelago.tmpl > apworld/addon_gzdoom_$*/archipelago.json
	sed -E "s,__WAD__,$*," apworld/addons/__init__.tmpl > apworld/addon_gzdoom_$*/__init__.py

install: apworlds
	cp -a ${APWORLDS}/*.apworld ~/.local/share/Archipelago/worlds

.PHONY: apworld install

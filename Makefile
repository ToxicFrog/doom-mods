MODS=libtooltipmenu gun-bonsai indestructable
COMPATS:=$(shell ls compat)

all: ${MODS} ${COMPATS}

clean: clean.libtooltipmenu clean.gun-bonsai clean.indestructable

clean.%:
	make -C $* TOPDIR=.. clean

deploy: all
	cp -L release/*-latest.pk3 release/*×*.pk3 /ancilla/installs/games/PC/DOOM/Laevis/

check: all
	gzdoom -iwad freedoom2.wad -file release/*-latest.pk3 +quit

${MODS}:
	$(MAKE) -C $@ TOPDIR=..

${COMPATS}:
	$(MAKE) -C compat TOPDIR=.. $@.pk3

.PHONY: all clean clean.* ${MODS} deploy

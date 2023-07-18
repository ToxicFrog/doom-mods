MODS=libtooltipmenu gun-bonsai indestructable
COMPATS:=$(shell ls compat)

all: ${MODS} ${COMPATS}

clean: clean.libtooltipmenu clean.gun-bonsai clean.indestructable

clean.%:
	make -C $* TOPDIR=.. clean

deploy: all
	cp release/*.pk3 /ancilla/installs/games/PC/DOOM/Laevis/

${MODS}:
	$(MAKE) -C $@ TOPDIR=..

${COMPATS}:
	$(MAKE) -C compat TOPDIR=.. $@.pk3

deploy: all
	cp -L release/*-latest.pk3 release/*×*.pk3 /ancilla/installs/games/PC/DOOM/Laevis/

.PHONY: all clean clean.* ${MODS} deploy

MODS=libtooltipmenu gun-bonsai indestructable

all: ${MODS}

clean: clean.libtooltipmenu clean.gun-bonsai clean.indestructable

clean.%:
	make -C $* TOPDIR=.. clean

deploy: all
	cp release/*.pk3 /ancilla/installs/games/PC/DOOM/Laevis/

${MODS}:
	$(MAKE) -C $@ TOPDIR=..

deploy: all
	cp -L release/*-latest.pk3 /ancilla/installs/games/PC/DOOM/Laevis/

.PHONY: all clean clean.* ${MODS} deploy

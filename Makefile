MODS=libtooltipmenu gun-bonsai indestructable gzap

all: ${MODS}
	$(MAKE) -C compat TOPDIR=..

stage:
	$(MAKE) -C gun-bonsai TOPDIR=.. stage
	$(MAKE) -C indestructable TOPDIR=.. stage
	$(MAKE) -C compat TOPDIR=.. stage
	$(MAKE) -C gzap TOPDIR=.. stage

clean: clean.libtooltipmenu clean.gun-bonsai clean.indestructable clean.gzap clean.compat

clean.%:
	make -C $* TOPDIR=.. clean

deploy: all
	cp -L release/*-latest.pk3 release/*×*.pk3 /ancilla/installs/games/PC/DOOM/Laevis/

check: all
	gzdoom -iwad freedoom2.wad -file release/*-latest.pk3 +quit

${MODS}:
	$(MAKE) -C $@ TOPDIR=..

.PHONY: all clean clean.* ${MODS} deploy

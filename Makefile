MODS=libtooltipmenu gun-bonsai indestructable

all: ${MODS}
	$(MAKE) -C compat TOPDIR=..

clean: clean.libtooltipmenu clean.gun-bonsai clean.indestructable clean.compat

clean.%:
	make -C $* TOPDIR=.. clean

deploy: all
	cp -L release/*-latest.pk3 release/*×*.pk3 /ancilla/installs/games/PC/DOOM/Laevis/

check: all
	gzdoom -iwad freedoom2.wad -file release/*-latest.pk3 +quit

${MODS}:
	$(MAKE) -C $@ TOPDIR=..

.PHONY: all clean clean.* ${MODS} deploy

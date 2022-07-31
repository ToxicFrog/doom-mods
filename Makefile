MODS=libtooltipmenu gun-bonsai indestructable

all: ${MODS}

clean: clean.libtooltipmenu clean.gun-bonsai clean.indestructable

clean.%:
	make -C $* TOPDIR=.. clean

${MODS}:
	$(MAKE) -C $@ TOPDIR=..

.PHONY: all clean clean.* ${MODS}

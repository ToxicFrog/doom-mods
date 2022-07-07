MODS=libntear laevis indestructable

all: ${MODS}

${MODS}:
	$(MAKE) -C $@ TOPDIR=..

.PHONY: all ${MODS}

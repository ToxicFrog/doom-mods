VERSION=0.6.5
MODS=laevis indestructable

all: ${MODS}

${MODS}:
	$(MAKE) -C $@ VERSION=${VERSION} TOPDIR=..

.PHONY: all ${MODS}

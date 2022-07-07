### Values to be provided by the caller before this file is included. ###

#NAME= name of the pk3
#VERSION= pk3 version
#LUMPS= list of top-level lump files and dirs
#ZSDIR= list of directories holding zscript to compile

### Values computed at include time ###

PK3=${TOPDIR}/release/${NAME}-${VERSION}.pk3
ifdef ZSDIR
	ZSCRIPT_AUTO=$(patsubst %.zs,%.zsc,$(shell find ${ZSDIR} -name "*.zs"))
	ZSCRIPT_TO_CLEAN=${ZSCRIPT_AUTO}
endif

### Rules ###

.PHONY: all clean.super

all: ${PK3}

clean.super:
	rm -f ${PK3} ${ZSCRIPT_TO_CLEAN}

${PK3}: ${LUMPS} ${ZSCRIPT} ${ZSCRIPT_AUTO}
	rm -f $@
	zip -qr $@ $^

%.zsc: %.zs
	${TOPDIR}/zspp $< $@


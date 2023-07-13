### Values to be provided by the caller before this file is included. ###

#NAME= name of the pk3
#VERSION= pk3 version
#LUMPS= list of top-level lump files and dirs
#ZSDIR= list of directories holding zscript to compile
#LIBTTM= path to libtooltipmenu to integrate, if any
#LIBTTM_PREFIX= prefix (e.g. TFIS) to use when specializing libtooltipmenu for this mod

### Values computed at include time ###

PK3=${TOPDIR}/release/${NAME}-${VERSION}.pk3
PK3LN=${TOPDIR}/release/${NAME}-latest.pk3
MOD_VERSION=${VERSION}+$(shell git rev-parse --short=8 HEAD)

ifdef ZSDIR
ZSCRIPT_AUTO=$(patsubst %.zs,%.zsc,$(shell find ${ZSDIR} -name "*.zs"))
ZSCRIPT_TO_CLEAN=${ZSCRIPT_AUTO}

ifdef LIBTTM
LIBTTM_ZS=${ZSDIR}/libtooltipmenu/TooltipListMenu.zsc
LIBTTM_ZS+=${ZSDIR}/libtooltipmenu/TooltipOptionMenu.zsc
LIBTTM_ZS+=${ZSDIR}/libtooltipmenu/Tooltips.zsc
ZSCRIPT+=${LIBTTM_ZS}
ZSCRIPT_TO_CLEAN+=${LIBTTM_ZS}
${ZSDIR}/libtooltipmenu/%:
	sed -E 's,TF_,${LIBTTM_PREFIX}_,g; s,ItemTooltip,Item${LIBTTM_PREFIX}_Tooltip,g' ${LIBTTM}/$* > $@

endif # libttm
endif # zsdir

### Rules ###

.PHONY: all clean.super clean

all: ${PK3}

clean.super:
	rm -f ${PK3} ${ZSCRIPT_TO_CLEAN}

clean: clean.super

${PK3}: ${LUMPS} ${ZSCRIPT} ${ZSCRIPT_AUTO}
	rm -f $@
	zip -qr $@ $^ --exclude @.pk3ignore
	ln -sf $@ "${PK3LN}"

%.zsc: %.zs
	MOD_VERSION=${MOD_VERSION} ${TOPDIR}/zspp $< $@


NAME=Laevis
VERSION=0.1.0
LUMPS=zscript.txt *.md MAPINFO MENUDEF CVARINFO KEYCONF
ZSDIR=ca.ancilla.laevis
LIBTTM=${TOPDIR}/libtooltipmenu/ca.ancilla.libtooltipmenu
LIBTTM_PREFIX=TFLV

include ${TOPDIR}/rules.make

check: ${PK3}
	gzdoom -iwad freedoom2.wad -file ${TOPDIR}/assets/LegenDoom_2.8.3.pk3 $^ +quit

COMPATS:=$(patsubst %/,${TOPDIR}/release/%.pk3,$(shell ls -d */))

all: ${COMPATS}

clean:
	rm -f ${COMPATS}

${TOPDIR}/release/%.pk3: %/zscript.txt
	zip --junk-paths -qr -0 $@ $<

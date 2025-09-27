COMPATS:=$(patsubst %/,${TOPDIR}/release/%.pk3,$(shell ls -d */))

all: ${COMPATS}

clean:
	rm -f ${COMPATS}

stage:
	git rm --cached --ignore-unmatch '${TOPDIR}/release/*×*'
	git add -f ${TOPDIR}/release/*×*

${TOPDIR}/release/%.pk3: %/ %/* %/*/* %/*/*/*
	rm -f $@
	(cd $< && zip -qr -0 ../$@ .)

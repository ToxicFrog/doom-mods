all: Laevis.pk3

Laevis.pk3: MAPINFO CVARINFO KEYCONF MENUDEF zscript.txt ca.ancilla.laevis/*.zs
	rm -f $@
	zip -r $@ $^

clean:
	rm -f Laevis.pk3

deploy: Laevis.pk3
	@#rm -f /ancilla/installs/games/PC/DOOM/test.pk3
	@#sleep 2
	@#cp test.pk3 /ancilla/installs/games/PC/DOOM/
	@#scp test.pk3 ben@durandal:/cygdrive/c/games/DOOM/


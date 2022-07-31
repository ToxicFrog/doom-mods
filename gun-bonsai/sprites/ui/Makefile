# LHUD: frame
# LHDW: weapon XP bar
# LHDP: player XP bar
# Positions are 2-4-6-8 clockwise from lower left.

FRAMES=LHUDA2.png LHUDA4.png LHUDA6.png LHUDA8.png
PLAYER=LHDPA2.png LHDPA4.png LHDPA6.png LHDPA8.png
WEAPON=LHDWA2.png LHDWA4.png LHDWA6.png LHDWA8.png
# desaturate the hud so it can be used with in-game colourization
IMFLAGS=-define modulate:colorspace=HSB -modulate 100,0

all: $(FRAMES) $(PLAYER) $(WEAPON)

clean:
	rm -rf $(FRAMES) $(PLAYER) $(WEAPON)

LHUDA%.png: hud.xcf Makefile
	convert "hud.xcf[0]" $(IMFLAGS) LHUDA2.png
	convert "hud.xcf[0]" $(IMFLAGS) -flip LHUDA4.png
	convert "hud.xcf[0]" $(IMFLAGS) -flip -flop LHUDA6.png
	convert "hud.xcf[0]" $(IMFLAGS) -flop LHUDA8.png

LHDWA%.png: hud.xcf Makefile
	convert "hud.xcf[1]" $(IMFLAGS) LHDWA2.png
	convert "hud.xcf[1]" $(IMFLAGS) -flip LHDWA4.png
	convert "hud.xcf[1]" $(IMFLAGS) -flip -flop LHDWA6.png
	convert "hud.xcf[1]" $(IMFLAGS) -flop LHDWA8.png

LHDPA%.png: hud.xcf Makefile
	convert "hud.xcf[2]" $(IMFLAGS) LHDPA2.png
	convert "hud.xcf[2]" $(IMFLAGS) -flip LHDPA4.png
	convert "hud.xcf[2]" $(IMFLAGS) -flip -flop LHDPA6.png
	convert "hud.xcf[2]" $(IMFLAGS) -flop LHDPA8.png

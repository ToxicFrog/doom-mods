# LHUD: frame
# LHDW: weapon XP bar
# LHDP: player XP bar
# Positions are 2-4-6-8 clockwise from lower left.

SKINS=A B C
DIRS=2 4 6 8
FRAMES=$(foreach skin,$(SKINS),$(foreach dir,$(DIRS),LHUD$(skin)$(dir).png))
PLAYER=$(foreach skin,$(SKINS),$(foreach dir,$(DIRS),LHDP$(skin)$(dir).png))
WEAPON=$(foreach skin,$(SKINS),$(foreach dir,$(DIRS),LHDW$(skin)$(dir).png))

all: $(FRAMES) $(PLAYER) $(WEAPON)

clean:
	rm -rf $(FRAMES) $(PLAYER) $(WEAPON)

# desaturate the A-hud so it can be used with in-game colourization
# B- and C-hud come pre-desaturated
IMFLAGS=-define modulate:colorspace=HSB -modulate 100,0
LHUDA%.png: hud.xcf
	convert "hud.xcf[0]" $(IMFLAGS) LHUDA2.png
	convert "hud.xcf[0]" $(IMFLAGS) -flip LHUDA4.png
	convert "hud.xcf[0]" $(IMFLAGS) -flip -flop LHUDA6.png
	convert "hud.xcf[0]" $(IMFLAGS) -flop LHUDA8.png

LHDWA%.png: hud.xcf
	convert "hud.xcf[1]" $(IMFLAGS) LHDWA2.png
	convert "hud.xcf[1]" $(IMFLAGS) -flip LHDWA4.png
	convert "hud.xcf[1]" $(IMFLAGS) -flip -flop LHDWA6.png
	convert "hud.xcf[1]" $(IMFLAGS) -flop LHDWA8.png

LHDPA%.png: hud.xcf
	convert "hud.xcf[2]" $(IMFLAGS) LHDPA2.png
	convert "hud.xcf[2]" $(IMFLAGS) -flip LHDPA4.png
	convert "hud.xcf[2]" $(IMFLAGS) -flip -flop LHDPA6.png
	convert "hud.xcf[2]" $(IMFLAGS) -flop LHDPA8.png

# The B- and C- frames use the same bars as the A-frame for now
LHDWB%.png: LHDWA%.png
	cp $< $@

LHDWC%.png: LHDWA%.png
	cp $< $@

LHDPB%.png: LHDPA%.png
	cp $< $@

LHDPC%.png: LHDPA%.png
	cp $< $@

# circlehud just needs to be flipflopped around
LHUDB%.png: circlehud.png
	cp circlehud.png LHUDB2.png
	convert circlehud.png -flip LHUDB4.png
	convert circlehud.png -flip -flop LHUDB6.png
	convert circlehud.png -flop LHUDB8.png

# pentahud has two versions so the pentagram always points the same way
LHUDC%.png: pentahud.png pentahudinverse.png
	cp pentahud.png LHUDC2.png
	cp pentahudinverse.png LHUDC4.png
	convert pentahudinverse.png -flop LHUDC6.png
	convert pentahud.png -flop LHUDC8.png

.PHONY: all clean

OBJEVENTGFXDIR := graphics/object_events/pics

$(OBJEVENTGFXDIR)/people/brendan/walking.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 2 -mheight 4

$(OBJEVENTGFXDIR)/people/brendan/running.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 2 -mheight 4

$(OBJEVENTGFXDIR)/people/may/walking.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 2 -mheight 4

$(OBJEVENTGFXDIR)/people/may/running.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 2 -mheight 4

$(OBJEVENTGFXDIR)/people/ruby_sapphire_brendan/walking.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 2 -mheight 4

$(OBJEVENTGFXDIR)/people/ruby_sapphire_brendan/running.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 2 -mheight 4

$(OBJEVENTGFXDIR)/people/ruby_sapphire_may/walking.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 2 -mheight 4

$(OBJEVENTGFXDIR)/people/ruby_sapphire_may/running.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 2 -mheight 4

# Region merge (Johto): Ruins of Alph sliding-puzzle tile sheets (32x32 frames)
SLIDINGPUZZLESDIR := graphics/sliding_puzzle/puzzles

$(SLIDINGPUZZLESDIR)/kabuto/tiles.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 4 -mheight 4

$(SLIDINGPUZZLESDIR)/omanyte/tiles.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 4 -mheight 4

$(SLIDINGPUZZLESDIR)/aerodactyl/tiles.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 4 -mheight 4

$(SLIDINGPUZZLESDIR)/ho_oh/tiles.4bpp: %.4bpp: %.png
	$(GFX) $< $@ -mwidth 4 -mheight 4

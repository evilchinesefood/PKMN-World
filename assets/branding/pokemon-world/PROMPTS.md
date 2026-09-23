# Generation prompts

Revision 02 prompts and edit references are recorded in [PROMPTS-REVISION-02.md](PROMPTS-REVISION-02.md).

Generated with the built-in `image_gen` tool on 2026-09-23. All edits use the original cover as the reference, except the WORLD-only variant, which uses the generated full logo. Masters retain the tool's original output and alpha channels. `export-gba.mjs` performs only technical size, palette and tile-format conversion for the game assets.

The logo, clean artwork, scenery and box-front requests succeeded. The three sprite-sheet requests did not produce deliverables; a sequential Charizard retry returned `moderation_blocked` at the output stage. The actual sprite deliverables reuse existing repo artwork, as documented in README.md. No CLI/API fallback was used; that alternative requires explicit opt-in and `OPENAI_API_KEY`.

## pokemon-world-logo

```text
Use case: background-extraction.
Asset type: standalone transparent PNG title logo for Pokémon World.
Input image: the supplied box cover is the edit target and exact logo reference.
Extract/reconstruct ONLY the entire two-line logo at the top of the supplied image. Top line text exactly "Pokémon" in the original distinctive chunky yellow letters, deep royal-blue outline and dark extruded edge, acute accent over é. Bottom line exactly "WORLD" in the original metallic white-silver to pale-gold beveled block capitals, navy outlines and depth, with a red-white Poké Ball replacing the O exactly as shown. Preserve the shapes, proportions, kerning, curved arch and stacked relationship in the reference extremely faithfully. Remove the small TM, all characters, sky, landscapes, light rays and every other element.
Composition: one centered tightly framed complete logo with generous 5% transparent padding, horizontal 2:1 canvas approximately 2048x1024. Highest clean edge quality. No redesign. No mockup. Background must be genuine RGBA alpha transparency, not a checkerboard drawing, not white or black. Preserve opaque white metal within letters and internal transparent openings.
```

## artwork-clean

```text
Use case: precise-object-edit.
Asset type: full-resolution clean key art, no text or packaging.
Input image: supplied Pokémon World cover is the edit target. The main illustration is already approved.
Remove the entire silver GAME BOY ADVANCE left sidebar and its black dividers; crop the artwork to its original illustrated area, approximately portrait 7:8 proportion. Remove the large Pokémon WORLD title at the top, tiny TM, all three region name plaques KANTO JOHTO HOENN and their Poké Ball icons. Fill every removed graphic naturally with matching detailed sky, clouds, ocean and islands.
Preserve the approved illustration as faithfully as possible: orange Charizard flying left with teal wings and flame; blue Feraligatr bursting through surf on right with red spines; large green Sceptile in the lower center with leafy limbs and tail, yellow back nodules and red belly stripe. Preserve their faces, poses, proportions, crisp dark ink contours and vibrant cel-shaded style. Preserve the luminous blue ocean globe and cyan crossing routes, sunburst horizon, island cities, volcanoes, autumn Japanese pagoda region right and lush tropical islands below. Keep the original relative locations and original rich colors. Seamlessly reconstruct only formerly hidden areas. Full-bleed illustration, no border, no lettering, no logos, no UI, no watermark. Large polished portrait PNG.
```

## title-background-master

```text
Use case: precise-object-edit.
Asset type: landscape background plate for an animated GBA title screen.
Input image: supplied cover is the reference and edit source for the world scenery.
Create a landscape 3:2 composition of ONLY the gorgeous island-world background beneath the cover's characters: luminous blue ocean curving across a globe, separated lush tropical island chains linked by fine pale-cyan luminous arcs, volcanic Kanto islands left, autumn red-gold Johto islands with Japanese pagoda right, emerald green Hoenn coast, bridges and small coastal towns foreground. Intense cobalt sky and airy white clouds, bright cyan horizon, clean rich cel-shaded anime game illustration exactly matching the input palette and inked detail. Expand/recompose the scenic plate to fill a 3:2 landscape frame. Preserve the cover's distinctive geography and atmosphere.
Remove ALL Pokémon characters entirely, ALL Pokémon World logos, region labels and badges, GAME BOY ADVANCE sidebar, TM and all typography. Fill their occluded areas with coherent sky, islands and ocean. Leave open blue sky across the upper third to allow a separate logo later. No enormous foreground objects. Full bleed landscape image, ideally 1536x1024, high quality, no framing. This is a scenery-only layer and must contain no characters and no text.
```

## box-front

```text
Use case: precise-object-edit.
Asset type: finished flat front cover artwork for a personal Game Boy Advance game box.
Input image: original Pokémon World cover is the edit target. Preserve the main artwork and logo very faithfully; it is approved.
Polish this into a convincing professionally printed North American early-2000s GBA front cover. Square flat front face only, large approximately 2048x2048, no perspective, no mockup, no fold lines. Silver brushed-metal platform stripe occupies the left 13%, black edge separator; correctly rendered large vertical "GAME BOY ADVANCE" running bottom to top, small GBA oval at the top. Main artwork at right must closely preserve the original Charizard upper left, Feraligatr upper right and Sceptile lower center, their recognizable faces and poses, vivid ocean island globe, volcanoes, pagoda, cities and connecting light trails.
Retain the exact reference's big yellow-and-blue "Pokémon" stacked over metallic white-to-gold "WORLD" with the Poké Ball O, placed across the upper part of the artwork. Do not redesign the logo. Retain the neat small colored region plaques with exact labels "KANTO", "JOHTO", "HOENN" in matching red, blue, green at the islands; refine alignment and breathing room. All elements belong to a single unified polished cel-shaded illustration.
Add small era-appropriate finishing details along the lower edge of the art panel where they do not cover Sceptile: classic black-and-white ESRB E badge at lower left, small gold oval Nintendo quality seal near lower right, compact red Nintendo oval in the lower right corner. Precisely legible typography, clear spacing and sharp print edges. Keep original saturation and lighting. No added slogans, no extra characters, no product photos, no barcodes on the front. Present the complete finished front graphic filling the canvas.
```

## charizard-sprites (unsuccessful request)

```text
Use case: style-transfer.
Asset type: production animation sprite sheet for a native Game Boy Advance title screen.
Input image: supplied box cover is the character identity, pose and palette reference.
Create ONE character's 4-frame animation sheet. EXACT grid 2 columns by 2 rows, square canvas 1024x1024. Each of four equal 512x512 cells contains one whole complete character at the SAME SCALE and root anchor, centered at (256,256), (768,256), (256,768), (768,768). At least 40px transparent padding around each sprite; no overlap or clipping. Reading order upper-left, upper-right, lower-left, lower-right makes a seamless idle motion loop. The body should remain registered in each cell; only the animated parts move. Clean GBA pixel art intended to become four 64x64 frames: logical square pixels enlarged 8x using nearest neighbor, strong 1px dark outline, clusters of flat color, around 15 colors for this character, no antialiasing, no gradients or blur. Match the reference character and bright palette. This is actual sprite artwork, not a concept diagram.
Background must be genuine alpha transparency everywhere outside the sprites. No grid lines, labels, text, frame numbers, checkerboard pattern, scenery, logo or decorations.
Subject: Charizard in the reference's dynamic three-quarter pose facing RIGHT, orange body, pale yellow belly, two horns, long flame-tipped tail, teal wing membranes. Full body, wings, feet and flame visible.
Four motion frames: wings middle / wings lifted slightly / wings middle / wings lowered slightly, flame changing subtly. Preserve identical head, face, belly and anatomy across all frames. Mouth open confidently like the reference, keep distinct arms and two legs. Wings fit inside every cell with room to move.
```

## feraligatr-sprites (unsuccessful request)

```text
Use case: style-transfer.
Asset type: production animation sprite sheet for a native Game Boy Advance title screen.
Input image: supplied box cover is the character identity, pose and palette reference.
Create ONE character's 4-frame animation sheet. EXACT grid 2 columns by 2 rows, square canvas 1024x1024. Each of four equal 512x512 cells contains one whole complete character at the SAME SCALE and root anchor, centered at (256,256), (768,256), (256,768), (768,768). At least 40px transparent padding around each sprite; no overlap or clipping. Reading order upper-left, upper-right, lower-left, lower-right makes a seamless idle motion loop. The body should remain registered in each cell; only the animated parts move. Clean GBA pixel art intended to become four 64x64 frames: logical square pixels enlarged 8x using nearest neighbor, strong 1px dark outline, clusters of flat color, around 15 colors for this character, no antialiasing, no gradients or blur. Match the reference character and bright palette. This is actual sprite artwork, not a concept diagram.
Background must be genuine alpha transparency everywhere outside the sprites. No grid lines, labels, text, frame numbers, checkerboard pattern, scenery, logo or decorations.
Subject: Feraligatr matching the right-side mascot in the reference, three-quarter pose facing LEFT, bright blue crocodilian body, cream jaw and belly, red back and head spikes, powerful forearms, white claws, open mouth and small white-blue water splash at feet. Full body, both feet and tail visible.
Four motion frames: neutral chest / chest rises slightly and forearms lift / neutral chest / chest settles and forearms lower, small water droplets shift. Strong stable root at the feet. Keep same head size, spike count, color and recognizable design across every frame.
```

## sceptile-sprites (unsuccessful request)

```text
Use case: style-transfer.
Asset type: production animation sprite sheet for a native Game Boy Advance title screen.
Input image: supplied box cover is the character identity, pose and palette reference.
Create ONE character's 4-frame animation sheet. EXACT grid 2 columns by 2 rows, square canvas 1024x1024. Each of four equal 512x512 cells contains one whole complete character at the SAME SCALE and root anchor, centered at (256,256), (768,256), (256,768), (768,768). At least 40px transparent padding around each sprite; no overlap or clipping. Reading order upper-left, upper-right, lower-left, lower-right makes a seamless idle motion loop. The body should remain registered in each cell; only the animated parts move. Clean GBA pixel art intended to become four 64x64 frames: logical square pixels enlarged 8x using nearest neighbor, strong 1px dark outline, clusters of flat color, around 15 colors for this character, no antialiasing, no gradients or blur. Match the reference character and bright palette. This is actual sprite artwork, not a concept diagram.
Background must be genuine alpha transparency everywhere outside the sprites. No grid lines, labels, text, frame numbers, checkerboard pattern, scenery, logo or decorations.
Subject: Sceptile matching the dominant green mascot in the reference, three-quarter dynamic pose facing LEFT, bright leaf-green gecko body, yellow eyes with red rims, red belly stripe, yellow nodules on back, leafy forearm blades and branching dark-green fern-like tail. Full body, head, hands, feet and tail visible.
Four motion frames: neutral alert stance / leaf tail and forearm blades lift slightly / neutral alert stance / leaf tail and blades lower slightly. Keep feet and torso stable and make a smooth leafy idle loop. Keep identical eye shapes, size, anatomy, colors and tail structure across frames.
```

## world-logo

```text
Use case: background-extraction.
Asset type: standalone WORLD wordmark with genuine transparent alpha background.
Input image: the supplied two-line transparent Pokémon World logo is the exact edit target.
Remove ONLY the entire top yellow Pokémon line. Preserve ONLY the bottom line "WORLD" EXACTLY as shown in the input. Do not retype or redesign it. Preserve every original curve, width, kerning, metallic silver-white-to-pale-gold beveled surface, navy dark-blue outline and deep blue extrusion. In particular the O is a red and white Poké Ball with central white circle and dark belt. This version must be a matching companion to that exact full logo.
Reframe/crop tightly around the complete WORLD wordmark with approximately 5% transparent padding and a wide 3:1 canvas. No title above it, no TM, no environment, no extra text, no ground shadow. True RGBA transparency outside and inside the letter openings, not black/white/checkerboard. Keep the white metal opaque. High resolution clean edges.
```

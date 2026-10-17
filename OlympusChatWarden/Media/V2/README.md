# Bronze artwork — 1.0 alpha2

Created with the built-in image-generation tool, using the user's original artwork and in-game Forever bronze screenshot as references. The tabard uses the supplied blue cloth, white mountain emblem and oval hardware reference. Two marked sidebar emblems are removed; the header's ChatWarden face shield is preserved and recolored.

Native assets are `Controls.tga`, `Panels.tga`, `Icons.tga` and `Ornament.tga` at 1024 square, plus `Logo.tga`, `Tabard.tga` and standalone `Books.tga` at 512 square. These are uncompressed 32-bit BGRA TGA files with true alpha and a top-left origin. PNG inspection copies are retained in the source workspace but omitted from the install ZIP.

The selected atlas sources are 1254 square. `Art.lua` uses recalibrated source coordinates normalized by 1254; technical conversion resizes the canvas uniformly to native texture dimensions. Icon slots preserve each crop's aspect ratio. No recoloring or background painting is done by the format-conversion script.

## Exact prompts and selected source files

### Controls

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-270bf94e-7fa1-4e91-b008-cfe19d488a71.png`.

Saved native asset: `OlympusChatWarden/Media/V2/Controls.tga`; inspection copy: `Controls.png`.

Use case: precise-object-edit. Asset type: production texture atlas for a World of Warcraft addon. Image 1 is the edit target: a 1024 by 1024 transparent atlas. Image 2 is a material-color reference only: the softer weathered brown-bronze metal of the native game UI at the bottom. Rework ONLY the bright yellow/gold metal into aged warm bronze: deep walnut-brown recesses, muted copper-bronze midtones, gentle pale bronze highlights. Reduce yellow saturation and the neon shine substantially. Preserve blue accents, red and green status colors, dark leather, parchment and text. Keep every existing component at exactly its current atlas coordinates and size on the 1024-square canvas, including the transparent padding in the bottom quarter. Do not rearrange, resize, add components or add labels. Keep all exterior areas truly transparent, not black or checkerboard. Preserve ornate craftsmanship and crisp edges.

### Panels

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-5c34a89b-5d5d-4e04-a5ae-abd550d26561.png`.

Saved native asset: `OlympusChatWarden/Media/V2/Panels.tga`; inspection copy: `Panels.png`.

Use case: precise-object-edit. Asset type: production texture atlas for a World of Warcraft addon. Image 1 is the edit target: a 1024 by 1024 transparent atlas. Image 2 is a material-color reference only: the softer weathered brown-bronze metal of the native game UI at the bottom. Rework ONLY the bright yellow/gold metal into aged warm bronze: deep walnut-brown recesses, muted copper-bronze midtones, gentle pale bronze highlights. Reduce yellow saturation and the neon shine substantially. Preserve blue accents, red and green status colors, dark leather, parchment and text. Keep every existing component at exactly its current atlas coordinates and size on the 1024-square canvas, including the transparent padding in the bottom quarter. Do not rearrange, resize, add components or add labels. Keep all exterior areas truly transparent, not black or checkerboard. Preserve ornate craftsmanship and crisp edges.

### Ornament

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-32604c39-cdd3-4250-81fe-94fdba5e1560.png`.

Saved native asset: `OlympusChatWarden/Media/V2/Ornament.tga`; inspection copy: `Ornament.png`.

Use case: precise-object-edit. Asset type: production texture atlas for a World of Warcraft addon. Image 1 is the edit target: a 1024 by 1024 transparent atlas. Image 2 is a material-color reference only: the softer weathered brown-bronze metal of the native game UI at the bottom. Rework ONLY the bright yellow/gold metal into aged warm bronze: deep walnut-brown recesses, muted copper-bronze midtones, gentle pale bronze highlights. Reduce yellow saturation and the neon shine substantially. Preserve blue accents, red and green status colors, dark leather, parchment and text. Keep every existing component at exactly its current atlas coordinates and size on the 1024-square canvas, including the transparent padding in the bottom quarter. Do not rearrange, resize, add components or add labels. Keep all exterior areas truly transparent, not black or checkerboard. Preserve ornate craftsmanship and crisp edges. Additional edit: on the lower-left books/candle/lantern decoration, remove the gold crest printed on the blue cloth draped over the standing book. Leave that cloth plain dark blue with its trim and natural folds. Keep the books, candle, lantern and their positions. The separate header crest elsewhere on the sheet must keep its design.

### Icons

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-a1377233-71ea-4273-b596-f82574a2fab5.png`.

Saved native asset: `OlympusChatWarden/Media/V2/Icons.tga`; inspection copy: `Icons.png`.

Use case: precise-object-edit. Asset type: transparent game UI icon atlas. Image 1 is the edit target. Image 2 is the bronze material reference at the bottom. Change only the bright yellow gold metal to weathered warm brown bronze with copper-bronze midtones, dark brown recesses and restrained pale highlights. Preserve every icon design, all blue/red/green/purple colors and parchment pages. Preserve the square canvas, all rows and columns, all component positions, shapes and sizes, and the large transparent bottom padding. No rearrangement and no new icons. True transparent exterior, no black background. This atlas must fit the same native UI coordinates.

### Logo

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-ceecb8da-f4a3-4042-abb1-21d85985be89.png`.

Saved native asset: `OlympusChatWarden/Media/V2/Logo.tga`; inspection copy: `Logo.png`.

Use case: precise-object-edit. Asset type: transparent Olympus ChatWarden game UI logo. Image 1 is the exact logo to edit. Image 2 is the bronze material reference at the bottom. Change only its bright yellow gold metal to weathered warm brown bronze, with copper midtones, darker brown recesses and restrained pale bronze highlights. Preserve the complete face shield identity, chat bubble and three dots, crown and leaves, blue gems and navy interior, shape, proportions, detail and centered framing. Do not use a lion. No text or new elements. True transparent exterior.

### Tabard

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-bc9dd6c9-99f5-4fb5-aa95-99e58e911fda.png`.

Saved native asset: `OlympusChatWarden/Media/V2/Tabard.tga`; inspection copy: `Tabard.png`.

Use case: background-extraction and precise-object-edit. Asset type: transparent guild-tabard decoration for Olympus ChatWarden's sidebar. Image 1 is the exact Olympus tabard badge to preserve and clean up at higher resolution. Image 2 confirms the guild's blue-and-white tabard and its white mountain silhouette, not a face or lion. Keep the first reference's oval bronze rim, hanging rich dark blue cloth, white edge trim and central white mountain crest, with a prominent central peak and smaller jagged peaks. Faithfully preserve that recognizable emblem and design. Refine its small raster edges into a crisp detailed fantasy game UI asset; do not change the mountain into an animal or other symbol. Weathered brown bronze hardware, gentle highlights, fabric folds. One centered complete badge with small margin on a square canvas. Remove the black exterior and make it truly transparent. No text, no person, no extra logos.


Final bronze refinement prompt:

Use case: precise-object-edit. Image 1 is the edit target, the Olympus guild tabard badge. Image 2 is ONLY a bronze material/color reference: match its muted brown/copper bronze UI frames. Change only the yellow-gold oval rim, studs and hardware of the tabard to that same softer aged brown bronze. Remove yellow-gold glare. Preserve the exact blue cloth, white mountain crest and white trim, folds, geometry, center position, all detail and true exterior alpha transparency. No new objects, no text and no redesign. Deliver the same square transparent composition.

### Books

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-51f9dcdd-dc67-4cc5-82dc-e310596ea536.png`.

Saved native asset: `OlympusChatWarden/Media/V2/Books.tga`; inspection copy: `Books.png`.

Use case: precise-object-edit and background-extraction. Asset type: one standalone transparent game UI decoration. Image 1 is the edit target, a bronze fantasy UI atlas. Extract ONLY the lower-left books, lantern and candle decoration into a new centered square transparent image. Preserve its stack of leather books, standing book draped in PLAIN dark blue cloth with no crest, lit ivory candle, bronze lantern, and the small blue gem and bronze corner attached to the lower-left base of that decoration. Preserve the warm brown-bronze style and detailed arrangement. Exclude every neighboring UI panel, vertical frame, header, banner, logo and detached blue gem. Especially exclude the adjacent tall vertical frame and its bottom gem that overlap the decoration's upper-right bounding rectangle. Output only the coherent books/candle/lantern/base decoration, complete and unclipped, with a small transparent margin and true alpha outside. No text or symbols on the cloth.

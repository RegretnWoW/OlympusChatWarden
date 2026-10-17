# Bronze guardian artwork — 1.0 alpha3

Created with the built-in image-generation tool from the user's supplied artwork, mountain crest and bronze UI references. `Controls`, `Panels`, `Icons`, `Ornament` and `Logo` are carried forward unchanged from alpha2. Their original generation details follow below. Separate floating Books/Tabard assets are replaced by Guardian.

Eight uncompressed, 32-bit BGRA TGA assets have a top-left origin and true alpha. Logo is 512 square; the seven other native assets are 1024 square. PNG inspection copies remain in source but are omitted from the install ZIP. Atlas crops use the 1254-square source coordinates. Guardian's source is 1240 × 1269; the native square canvas is displayed at that original aspect ratio. Format conversion performs technical resizing only, with no painted or recolored pixels.

Olympus launcher integration uses the named windows and public minimap click handler in [Olympus UI.lua](https://github.com/dnl-gentile/olympus-addon/blob/main/Olympus/UI.lua). No private namespace is accessed.

## New assets — exact prompts and selected sources

### Guardian

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-260369cc-e931-4dc1-bb5e-4417d89a6ccc.png`.

Native asset: `Guardian.tga`; inspection copy: `Guardian.png`.

Use case: compositing and stylized-concept. Asset type: one cohesive corner ornament for a Greek mythology themed chat protection addon in a fantasy game. Image 1 is a reference for the current bronze/blue UI and the available bottom-left sidebar space. Image 2 is the exact Olympus guild mountain emblem reference, to incorporate physically into the artwork. Replace the separate floating books and tabard with a single powerful sculpted Poseidon sea-guardian ornament: a stern bearded Greek sea-god face in aged brown bronze, a trident, and a coiled sea-serpent or hippocampus guarding a deep navy shield bearing the recognizable WHITE MOUNTAIN CREST from image 2. The crest is attached to the armor/shield, never a floating separate logo. Match muted copper-bronze UI metal, dark brown recesses, restrained ivory highlights and deep sapphire accents. Give it a crafted fantasy MMORPG relief style, bold readable silhouettes at small UI size. Compose it as a narrow upright ornament whose left edge joins a vertical bronze frame rail and whose base joins a horizontal bronze frame rail: a connected L-shaped lower-left corner. Artwork must visually hug the bottom and left rails. It must fit below sidebar navigation and not intrude into content. No books or candle needed. No lettering, no extra emblems, no scene background. Transparent exterior. One complete unclipped centered design with minimal margin.

### Status

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-8b0b1408-a14b-4c3b-bf48-c247b872d647.png`.

Native asset: `Status.tga`; inspection copy: `Status.png`.

Use case: style-transfer. Asset type: a production game UI icon atlas with 12 separate icons. Image 1 is the style reference: muted bronze, blue accents, polished fantasy icons. Produce a square transparent atlas in a STRICT uniform grid of FOUR COLUMNS and THREE ROWS, with equal cell sizes, generous transparent gutters, each icon centered in its cell. No text, labels or frames around the whole atlas. Row 1, left to right: filtering ON (luminous green glass orb with bronze rim), Shield ON (bronze shield with bright sapphire center), Chat Capture ON (open parchment book in bronze binding), Mentions ON (bronze @ symbol with a blue accent). Row 2 contains the corresponding OFF states in the exact same column order: unlit smoke-gray orb, inactive dark shield, closed gray book, dim dark @. Give each off icon a small clearly readable bronze minus badge at its lower-right so state is distinguishable without relying only on color. Row 3: Reports (stack of parchment documents with bronze clipboard and blue wax seal), Updates (a bronze notification bell with a small sapphire starburst, clearly different from Reports), Olympus launcher available (the reference's circular bronze Greek lambda/Olympus symbol), Olympus unavailable (the same symbol in dim gunmetal with a minus badge). Preserve a consistent style and visual size, no clipping or touching between cells. True alpha transparency between every icon and outside the icons.

### Tabs

Selected generated source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-bd7fea2f-55aa-4618-aada-9db6f4a8751f.png`.

Native asset: `Tabs.tga`; inspection copy: `Tabs.png`.

Use case: precise-object-edit. Asset type: a clean production tab/button atlas. Image 1 is a style reference only for bronze borders, navy fill and blue active glow. Generate SIX unlabeled wide horizontal tabs in one vertical column on a square transparent canvas. All six have identical outer shape and size, are perfectly aligned, and have substantial transparent spacing between them. From top to bottom: selected blue; unselected charcoal; hovered blue; pressed blue; disabled charcoal; a thin full-width bronze divider with a small sapphire centerpiece and solid bronze endcaps. The five tabs are simple cohesive beveled rectangles with small angular corners and continuous straight borders that can be sliced horizontally and vertically. No overlapping flared feet, no decorative pieces protruding beyond the tab rectangle, no panels underneath, no baked text or example labels. Dark opaque interior, muted brown/copper-bronze trim matching the reference. Keep the center fill clean and text-free, borders crisp, all components complete and unclipped. Divider must have continuous horizontal rails extending from both sides of its gem to the endcaps so it connects to panel borders. True transparent exterior and gutters.

## Carried-forward asset provenance

### Controls

Source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-270bf94e-7fa1-4e91-b008-cfe19d488a71.png`.

Use case: precise-object-edit. Asset type: production texture atlas for a World of Warcraft addon. Image 1 is the edit target: a 1024 by 1024 transparent atlas. Image 2 is a material-color reference only: the softer weathered brown-bronze metal of the native game UI at the bottom. Rework ONLY the bright yellow/gold metal into aged warm bronze: deep walnut-brown recesses, muted copper-bronze midtones, gentle pale bronze highlights. Reduce yellow saturation and the neon shine substantially. Preserve blue accents, red and green status colors, dark leather, parchment and text. Keep every existing component at exactly its current atlas coordinates and size on the 1024-square canvas, including the transparent padding in the bottom quarter. Do not rearrange, resize, add components or add labels. Keep all exterior areas truly transparent, not black or checkerboard. Preserve ornate craftsmanship and crisp edges.

### Panels

Source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-5c34a89b-5d5d-4e04-a5ae-abd550d26561.png`.

Use case: precise-object-edit. Asset type: production texture atlas for a World of Warcraft addon. Image 1 is the edit target: a 1024 by 1024 transparent atlas. Image 2 is a material-color reference only: the softer weathered brown-bronze metal of the native game UI at the bottom. Rework ONLY the bright yellow/gold metal into aged warm bronze: deep walnut-brown recesses, muted copper-bronze midtones, gentle pale bronze highlights. Reduce yellow saturation and the neon shine substantially. Preserve blue accents, red and green status colors, dark leather, parchment and text. Keep every existing component at exactly its current atlas coordinates and size on the 1024-square canvas, including the transparent padding in the bottom quarter. Do not rearrange, resize, add components or add labels. Keep all exterior areas truly transparent, not black or checkerboard. Preserve ornate craftsmanship and crisp edges.

### Ornament

Source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-32604c39-cdd3-4250-81fe-94fdba5e1560.png`.

Use case: precise-object-edit. Asset type: production texture atlas for a World of Warcraft addon. Image 1 is the edit target: a 1024 by 1024 transparent atlas. Image 2 is a material-color reference only: the softer weathered brown-bronze metal of the native game UI at the bottom. Rework ONLY the bright yellow/gold metal into aged warm bronze: deep walnut-brown recesses, muted copper-bronze midtones, gentle pale bronze highlights. Reduce yellow saturation and the neon shine substantially. Preserve blue accents, red and green status colors, dark leather, parchment and text. Keep every existing component at exactly its current atlas coordinates and size on the 1024-square canvas, including the transparent padding in the bottom quarter. Do not rearrange, resize, add components or add labels. Keep all exterior areas truly transparent, not black or checkerboard. Preserve ornate craftsmanship and crisp edges. Additional edit: on the lower-left books/candle/lantern decoration, remove the gold crest printed on the blue cloth draped over the standing book. Leave that cloth plain dark blue with its trim and natural folds. Keep the books, candle, lantern and their positions. The separate header crest elsewhere on the sheet must keep its design.

### Icons

Source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-a1377233-71ea-4273-b596-f82574a2fab5.png`.

Use case: precise-object-edit. Asset type: transparent game UI icon atlas. Image 1 is the edit target. Image 2 is the bronze material reference at the bottom. Change only the bright yellow gold metal to weathered warm brown bronze with copper-bronze midtones, dark brown recesses and restrained pale highlights. Preserve every icon design, all blue/red/green/purple colors and parchment pages. Preserve the square canvas, all rows and columns, all component positions, shapes and sizes, and the large transparent bottom padding. No rearrangement and no new icons. True transparent exterior, no black background. This atlas must fit the same native UI coordinates.

### Logo

Source: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-ceecb8da-f4a3-4042-abb1-21d85985be89.png`.

Use case: precise-object-edit. Asset type: transparent Olympus ChatWarden game UI logo. Image 1 is the exact logo to edit. Image 2 is the bronze material reference at the bottom. Change only its bright yellow gold metal to weathered warm brown bronze, with copper midtones, darker brown recesses and restrained pale bronze highlights. Preserve the complete face shield identity, chat bubble and three dots, crown and leaves, blue gems and navy interior, shape, proportions, detail and centered framing. Do not use a lion. No text or new elements. True transparent exterior.

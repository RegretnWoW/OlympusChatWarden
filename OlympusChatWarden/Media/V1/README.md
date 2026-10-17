# Olympus ChatWarden 1.0 artwork

The user supplied the logo, icon, panel, control and ornament sheets for this addon on 2026-10-13. The gold face/chat shield is the chosen identity. Lion branding in the reference sheets is not used as the ChatWarden logo.

## Native game assets

`Logo.tga` is a 512 x 512 transparent icon. `Icons.tga`, `Panels.tga`, `Controls.tga` and `Ornament.tga` are 1024 x 1024 texture atlases. They are uncompressed 32-bit BGRA TGA files with true alpha and a top-left origin. `Art.lua` selects native texture coordinates and assembles scalable borders and control states; live UI text is drawn by WoW. PNG copies in the source workspace are inspection references and are omitted from the private install ZIP.

Sources in the user's Downloads folder:

- `ChatGPT Image Oct 13, 2026, 05_02_24 PM.jpg` — logo.
- `ChatGPT Image Oct 13, 2026, 05_06_33 PM.png` — icons.
- `ChatGPT Image Oct 13, 2026, 05_06_40 PM.png` — panels and rows.
- `ChatGPT Image Oct 13, 2026, 05_06_59 PM.png` — controls.
- `Ornate Gold and Blue Fantasy UI Sheet.png` — ornaments.

## Logo background extraction

The built-in image generation tool removed the exterior background from the supplied logo. Saved result: `C:/Users/Admin/.codex/generated_images/01a12586-8be1-7462-b502-559989ddae62/exec-fac964b9-5ae6-482f-9e30-4e1d585dbc10.png`. The addon-ready result is `OlympusChatWarden/Media/V1/Logo.tga`, with a PNG inspection copy beside it.

Exact prompt:

> Use case: background-extraction. Edit target: attached Olympus ChatWarden gold face shield logo. Prepare this exact existing logo as a transparent game UI icon. Remove only the dark teal exterior background outside the shield and decorative leaf silhouette. Preserve the gold face, gold shield border, crown and leaves, navy blue inset panels, gold chat bubble with three gold dots, blue gems, proportions, and every design detail. Do not redesign the identity, do not use a lion, and do not add text. Keep all dark navy surfaces inside the shield opaque. Output one centered cutout with true alpha transparency outside, a small transparent margin, the complete silhouette unclipped, crisp detailed edges. Asset intended for the current addon.

The remaining UI assets use the supplied sheets directly, with technical resizing, transparent padding and format conversion. No optional rule vocabulary or signing material is part of these assets.

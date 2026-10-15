# Artwork

The current 1.0 alpha7 workspace uses warm bronze frames, blue active controls and the ChatWarden face-shield logo. A single Poseidon/sea-dragon corner relief includes the Olympus mountain crest on its shield and joins the bottom-left sidebar rail. Status on/off icons, distinct Reports/Updates icons, and clean tabs use generated assets. Details and Actions have separate framed boxes. Dark backings are inset within transparent bronze corners; the scale rail is a background texture beneath the thumb.

Central read-only documents use the V4 parchment, retaining the existing design with dark brown text, sepia headings and restrained blue/green/amber/red accents. Lists, settings, details/actions, editable inputs and export JSON remain dark gray. The Olympus launcher references the public minimap icon, tries `Interface\AddOns\Olympus\media\logo128` after a failed load, and falls back to the bundled Olympus symbol. No Olympus texture is redistributed. Source: https://github.com/dnl-gentile/olympus-addon/blob/main/Olympus/Core.lua.

Native assets and exact prompts are documented in [Media/V4/README.md](Media/V4/README.md). Labels, counts and controls remain native interactive UI. `Media/Bar.tga` is the inline redaction texture and `Media/IconScroll.tga` remains for older fallback surfaces. Blizzard textures are referenced from the game, not redistributed.

V1 and V2 artwork remains in the source workspace and preserved earlier ZIPs; current install archives include only V4.

Alpha7 uses eight cleaned V4 assets from built-in imagegen, preserving the bronze style and interior dark recesses while reducing the exterior black fringe. Unread rows combine a native translucent blue wash with a sapphire crop from the main logo. V1–V3 remain in the source workspace and prior archives. Exact edit prompts and follow-up alpha cleanup prompts are in Media/V4/README.md.

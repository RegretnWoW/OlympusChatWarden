# Fireside — Third Dimension: textured scene v0.2

Native visual feasibility is **unverified**. This is a test candidate, not a proven playable build or production conversion. No WoW client/assets are installed in Codex Cloud. An accepted model request and loaded bounds do not establish that a usable house renders.

Base: `9bc2326f67532c548102caa831b20af2234d6bfe`.
Branch: `experiment/minimal-3d-textured-scene`.

The original build remains on `experiment/minimal-3d-house`. This second candidate keeps its house/table/player and controls, replaces the native factory-floor model with a wood-textured flat ground presentation, and adds the existing daytime sky/cloud artwork over opaque blue. Transparent source pixels reveal blue, never black. Camera height stays above the ground. No in-game success is assumed.

## Install and run one manual test

Extract `Fireside3DExperiment` directly into Forever's `Interface/AddOns/`. Enable it (load out-of-date addons if needed). The production Fireside addon, Olympus addon and guild membership are **not** dependencies. No SavedVariables are declared; all experimental state is discarded on reload. No database, migration, player history, credentials or networking code is loaded.

1. Outside combat, run `/fs3d`. Only a house is requested initially. Right-drag inside the viewport to orbit and pitch; wheel changes camera distance. Inspect the whole model, its floor and any doorway. If invisible, a flat facade, or otherwise unusable, `/fs3d next` tries the next candidate. There are exactly three; if none is usable, stop and report `/fs3d report` output. No replacement geometry or image is used.
2. If a real usable building is visible, `/fs3d accept` adds your native character, one inn table at the house center over the textured ground with a sky/cloud backdrop. Confirm the house, table and player render with shared depth/occlusion while rotating fully around them. The ground and sky are presentation layers behind that native scene. API loading status alone is insufficient. The report records your explicit house confirmation only, not a claim about the remaining criteria.
3. Keep the pointer inside the viewport and press WASD. Movement is camera-relative at 4 world units/sec; facing follows motion. Right-drag rotates/pitches the follow camera. Move around the house and inspect the table inside from several angles. Escape, closing, leaving the viewport, editing chat or entering combat releases experimental input. Opening in combat is blocked; entering combat closes it. Test normal WoW controls after closing.
4. House collision defaults to a solid bounding rectangle. If the mesh actually has an accessible interior, `/fs3d interior` enables an **approximate** rectangular wall shell with a centered doorway on authored negative Y. This is not mesh-derived collision. If its doorway is elsewhere or the building is solid, leave the solid mode enabled and inspect from outside. `/fs3d floor <units>` lowers the house by that many units (range -15 to 15) to align its actual floor with the table/walking plane; all changes are session-only. Do not claim entry works if the visible opening/floor does not align. No stairs, slopes, jump, roof/ceiling collision or camera-wall collision is implemented.
5. Run `/fs3d report` and report what rendered, movement/camera behavior, interior availability and any Lua errors from this single session. If furniture fails to load, movement waits; report its status rather than treating this as success.

## Exact asset references

| Role | FileDataID | Client path |
|---|---:|---|
| First house candidate (M2) | 190430 | `world/azeroth/swamposorrow/passivedoodads/waterhuts/waterhut01.m2` |
| Second house candidate (M2) | 191492 | `world/expansion01/doodads/bladesedge/ogrila/ogrilahut/ogrila_hut.m2` |
| Last house candidate (WMO probe) | 106965 | `world/wmo/azeroth/buildings/human_farm/farm.wmo` |
| One furniture object | 198603 | `world/generic/human/passive doodads/tables/inntable.m2` |
| Player | current unit | `SetModelByUnit('player', true, true)` |

Source: [wowdev verified listfile](https://github.com/wowdev/wow-listfile/releases/latest/download/verified-listfile.csv), resolved during this experiment. These are filename/ID references, **not Forever availability or render certifications**. WMO is deliberately tested with the same native `SetModelByFileID` entry point; no WMO loader or world renderer is implemented. If Forever rejects WMO there is no workaround in this build. M2 huts may have closed interiors or raised floors. House scale normalizes its largest horizontal bound to 12 world units.

## Files and engine dependencies

All changes are new under `Fireside3DExperiment/`; no production file is modified.

- `Fireside3DExperiment.toc`: isolated addon; no dependencies or SavedVariables.
- `Prototype.lua`: staged house probe, input, scene and camera controller.
- `Background.lua`: sky/ground presentation using the same camera shot and inverse projection of the existing engine. The flat ground uses 128 textured strips, with approximate UV interpolation within each strip. This is not a general terrain renderer.
- `Media/Ground.tga`: byte-identical copy of `OlympusChatWarden/Media/WorldUI38/Wood.tga`.
- `Media/Sky.tga`: byte-identical copy of `OlympusChatWarden/Media/World52/a2-sky-day-0-0.tga`.
- `Media/Clouds.tga`: byte-identical copy of `OlympusChatWarden/Media/World50/a2-cloud-far-left-0-0.tga`.

Only these three existing images are bundled. Sky/cloud UVs omit unused transparent image padding; an opaque blue backing fills every gap. The background is a fixed backdrop, not a panoramic skybox.
- `Vendor/WardenNativeScene.lua`, `Vendor/WardenSceneObjectControls.lua`: **byte-identical copies** from the base commit, loaded into this addon's private namespace. Reuse covers ModelScene, bounds, positioning/scale, camera/projection, swept collision and native animation. No engine rewrite. Lighting uses native calls directly; unused optional production features are not invoked.
- `Checks.lua`: pure engine checks, not loaded by the TOC and not a renderer/simulator.
- `README.md`: integration and test instructions.

All native actors use one ModelScene/depth buffer. The projected texture ground is a backdrop plane, not a native depth-writing floor mesh; native below-floor clipping, terrain height and camera-wall collision are not provided. Its projection shares the existing mathematical FOV convention; actual Forever viewport registration needs the pending in-game check. No per-actor compositing or z-order tricks. The movement plane is flat; the mesh's visual floor, native depth buffer and interior topology need in-client inspection. Missing animation probe support is reported by the reused engine; movement may render without walk animation if a native sequence is unavailable. No WoW models or WoW textures are bundled; the three existing Fireside background images above are included for standalone installation.

## Cloud validation and integration

From the checkout root, use Lua 5.1:

```
find Fireside3DExperiment -name '*.lua' -exec luac5.1 -p {} \;
lua5.1 Fireside3DExperiment/Checks.lua
```

Syntax, pure collision/projection and packaging checks are cloud checks only. No existing test suite or package scripts are checked in. No visual success criteria have been marked passed.

For the Pro account: apply the supplied patch on a new branch based on the stabilized production version, or copy the changed-files ZIP's relative paths. Keep this standalone addon for the first test; it does not depend on a particular production database version. Compare the two vendor files with the newer engine before deliberately adopting later engine changes; do not overwrite the production renderer with these copies. Integrate only after the native house test succeeds. Do not merge scenes or migrate data as part of this experiment. Existing source licensing remains applicable.

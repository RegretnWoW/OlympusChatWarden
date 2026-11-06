# Fireside — Third Dimension: journal and showcase scene v0.4

Native visual feasibility is **unverified**. This is a test candidate, not a proven playable build or production conversion. No WoW client/assets are installed in Codex Cloud. An accepted model request and loaded bounds do not establish that a usable house renders.

Base: `9bc2326f67532c548102caa831b20af2234d6bfe`.
Branch: `experiment/minimal-3d-interactions`.

The original build remains on `experiment/minimal-3d-house`. The textured build remains on `experiment/minimal-3d-textured-scene`. This candidate keeps the house/table/player, wood ground, sky/cloud backdrop and camera controls, and includes a clickable chair, exactly two generic stationary NPCs, an interior table-top journal and an interior badge/memento shelf. Transparent source pixels reveal blue, never black. Camera height stays above the ground. No in-game success is assumed.

## Install and run one manual test

Extract `Fireside3DExperiment` directly into Forever's `Interface/AddOns/`. Enable it (load out-of-date addons if needed). The production Fireside addon, Olympus addon and guild membership are **not** dependencies. No SavedVariables are declared; all experimental state is discarded on reload. No database, migration, player history, credentials or networking code is loaded.

1. Outside combat, run `/fs3d`. Only a house is requested initially. Right-drag inside the viewport to orbit and pitch; wheel changes camera distance. Inspect the whole model, its floor and any doorway. If invisible, a flat facade, or otherwise unusable, `/fs3d next` tries the next candidate. There are exactly three; if none is usable, stop and report `/fs3d report` output. No replacement geometry or image is used.
2. If a real usable building is visible, `/fs3d accept` adds your native character, one inn table at the house center, a chair outside on the left, two generic human NPCs (inside the house footprint and outside on the right), a table-top journal and a display shelf inside the house footprint, over the textured ground with a sky/cloud backdrop. Confirm the house, table and player render with shared depth/occlusion while rotating fully around them. The ground and sky are presentation layers behind that native scene. Chair height and body pose must be checked on your native race/model; the demo starts with the existing production chair offsets. API loading status alone is insufficient. The report records your explicit house confirmation only, not a claim about the remaining criteria.
3. Keep the pointer inside the viewport and press WASD. Movement is camera-relative at 4 world units/sec; facing follows motion. Right-drag rotates/pitches the follow camera. Move around the house and inspect the table inside from several angles. Escape, closing, leaving the viewport, editing chat or entering combat releases experimental input. Opening in combat is blocked; entering combat closes it. Test normal WoW controls after closing.
4. House collision defaults to a solid bounding rectangle. If the mesh actually has an accessible interior, `/fs3d interior` enables an **approximate** rectangular wall shell with a centered doorway on authored negative Y. This is not mesh-derived collision. If its doorway is elsewhere or the building is solid, leave the solid mode enabled and inspect from outside. `/fs3d floor <units>` lowers the house by that many units (range -15 to 15) to align its actual floor with the table/walking plane; all changes are session-only. Do not claim entry works if the visible opening/floor does not align. No stairs, slopes, jump, roof/ceiling collision or camera-wall collision is implemented.
5. Walk freely over to the outside chair and left-click its native projected hitbox. The existing Fireside path planner finds an approach around props and NPCs, then its seating state machine settles the character onto the chair and holds the first supported chair pose (102/103/104). Right-drag to inspect while seated. Press WASD or click the chair again to stand; standing returns to the approach point before free movement resumes. WASD cancels a pending chair approach. Closing the window cancels that walk. If a required animation is unsupported, the interaction reports it instead of inventing success.
6. Check that both NPCs render and block walking through their bodies. These are stationary generic demo humans, not remembered players or multiplayer participants. The inside NPC is inside the authored footprint; a closed or unsupported house may hide it. Test its visibility from an actual opening if present. No dialog/AI or production player-history access is included.
7. If the real house has a usable interior, enable the existing `/fs3d interior` doorway trial and enter. Click the journal on the central table. The player approaches the table, the book requests its native open sequence, and a close-up **DEMO JOURNAL** opens with six synthetic pages. Turn Previous/Next, close/reopen/flip its cover using the existing cover controls, then Return to scene. Escape returns immediately. Confirm you can walk again and the native book closes. This tests presentation, not production history ingestion or narrative generation.
8. Click the shelf inside, on the opposite side to the inside NPC. Approach, inspect seven demo badges and their regional mementos, select two slots to swap, remove a selected badge, save the session, make another change and Cancel edits. Return and reopen to verify the session layout. Restore samples if desired. These are demo art, not earned rewards, and reset on reload. A blocked route rejects the click rather than teleporting through walls. If the house has no accessible interior, report that limit instead of treating interior interactions as passed.
9. Run `/fs3d report` and report what rendered, movement/camera behavior, interior availability and any Lua errors from this single session. If furniture fails to load, movement waits; report its status rather than treating this as success.

## Exact asset references

| Role | FileDataID | Client path |
|---|---:|---|
| First house candidate (M2) | 190430 | `world/azeroth/swamposorrow/passivedoodads/waterhuts/waterhut01.m2` |
| Second house candidate (M2) | 191492 | `world/expansion01/doodads/bladesedge/ogrila/ogrilahut/ogrila_hut.m2` |
| Last house candidate (WMO probe) | 106965 | `world/wmo/azeroth/buildings/human_farm/farm.wmo` |
| Table | 198603 | `world/generic/human/passive doodads/tables/inntable.m2` |
| Clickable chair | 198114 | `world/generic/human/passive doodads/chairs/generalchairhighend01.m2` |
| Inside NPC | display 1276 | Existing `WardenNativeScene.BodyDisplay({raceID=1,sex=2})` |
| Outside NPC | display 176 | Existing `WardenNativeScene.BodyDisplay({raceID=1,sex=3})` |
| Journal prop | 200912 | `world/goober/g_bookopenmediumbrown.m2` |
| Display shelf | 242995 | `world/expansion02/doodads/dalaran/dalaran_bookcase_empty_01.m2` |
| Player | current unit | `SetModelByUnit('player', true, true)` |

Source: [wowdev verified listfile](https://github.com/wowdev/wow-listfile/releases/latest/download/verified-listfile.csv), resolved during this experiment. These are filename/ID references, **not Forever availability or render certifications**. WMO is deliberately tested with the same native `SetModelByFileID` entry point; no WMO loader or world renderer is implemented. If Forever rejects WMO there is no workaround in this build. M2 huts may have closed interiors or raised floors. House scale normalizes its largest horizontal bound to 12 world units.

## Files and engine dependencies

All changes are new under `Fireside3DExperiment/`; no production file is modified.

- `Fireside3DExperiment.toc`: isolated addon; no dependencies or SavedVariables.
- `Prototype.lua`: staged house probe, input, scene and camera controller.
- `Interactions.lua`: adapted `SeatPlayer`, `UpdatePlayerSeat`, `LeavePlayerSeat` and `InteractPlayer` from production `WardenWorldRealm.lua` at the base commit. Production UI/preferences hooks are removed, `attendant` is bound to the experimental `player`, and navigation is supplied by the demo. Approach routing, bounds-based picking, seat offset, pose probes and animation playback reuse the existing engine.
- `WorldSpace.lua`: scene-specific world XYZ placement, collision basis, stable model anchors and native ground-plane mapping. Loaded after the unchanged vendor copies, it overrides only this addon's private namespace and engine instance.
- `Background.lua`: sky/ground presentation using the native world-plane mapping from WorldSpace.lua. The flat ground uses 128 textured strips, with approximate UV interpolation within each strip. This is not a general terrain renderer.
- `Media/Ground.tga`: byte-identical copy of `OlympusChatWarden/Media/WorldUI38/Wood.tga`.
- `Media/Sky.tga`: byte-identical copy of `OlympusChatWarden/Media/World52/a2-sky-day-0-0.tga`.
- `Media/Clouds.tga`: byte-identical copy of `OlympusChatWarden/Media/World50/a2-cloud-far-left-0-0.tga`.

The three background images and six selected library images are bundled; no full production asset library is included. Sky/cloud UVs omit unused transparent image padding; an opaque blue backing fills every gap. The background is a fixed backdrop, not a panoramic skybox.
- `Vendor/WardenNativeScene.lua`, `Vendor/WardenSceneObjectControls.lua`: **byte-identical copies** from the base commit, loaded into this addon's private namespace. Reuse covers ModelScene, bounds, positioning/scale, camera/projection, swept collision and native animation. No engine rewrite. Lighting uses native calls directly; unused optional production features are not invoked.
- `Checks.lua`: pure engine checks, not loaded by the TOC and not a renderer/simulator.
- `README.md`: integration and test instructions.

All native actors use one ModelScene/depth buffer. The textured ground is a world Z=0 presentation plane derived from native projection, not a native depth-writing floor mesh; native below-floor clipping, terrain height and camera-wall collision are not provided. Actual Forever registration still needs the pending in-game check. No per-actor compositing or z-order tricks. The movement plane is flat; the mesh's visual floor, native depth buffer and interior topology need in-client inspection. Missing animation probe support is reported by the reused engine; movement may render without walk animation if a native sequence is unavailable. No WoW models or WoW textures are bundled; the existing Fireside background and selected library images are included for standalone installation.

## Cloud validation and integration

From the checkout root, use Lua 5.1:

```
find Fireside3DExperiment -name '*.lua' -exec luac5.1 -p {} \;
lua5.1 Fireside3DExperiment/Checks.lua
lua5.1 Fireside3DExperiment/LibraryChecks.lua
```

Syntax, pure collision/projection, chair state-machine, animation capability, NPC clearance and packaging checks are cloud checks only. No existing test suite or package scripts are checked in. No visual success criteria have been marked passed. The seat-controller checks use actor records and record native calls; they do not emulate or validate WoW rendering/animation playback.

For the Pro account: apply the supplied patch on a new branch based on the stabilized production version, or copy the changed-files ZIP's relative paths. Keep this standalone addon for the first test; it does not depend on a particular production database version. Compare the two vendor files with the newer engine before deliberately adopting later engine changes; do not overwrite the production renderer with these copies. Integrate only after the native house test succeeds. Do not merge scenes or migrate data as part of this experiment. Existing source licensing remains applicable.

## Critical perspective separation (v0.3.1)

Audited `WardenNativeScene` world/placement/scale/projection/footprint code, `WardenSceneObjectControls` collision/picking, and `WardenWorldRealm` floor registration, ground offsets, layered occlusion and contact shadows. The latter production module is not loaded by this addon.

- **World coordinates:** actor positions, navigation, seat locations and the ground all use explicit X/Y/Z, ground Z=0. WorldSpace replaces the authored-shot basis only in the experimental namespace. Camera changes never reauthor positions or colliders.
- **Scale and pivots:** model dimensions are set once at load. Stable model-space pivot alignment and the pre-existing model-scaled native API translation conversion remain at the placement boundary; neither uses distance, FOV, screen position or viewport scale. No per-frame perspective sizing or animation-bounds recentering is applied. `floorUV`, legacy `groundOffset` and authored-shot facing compensation are ignored. `/fs3d floor` remains an intentional world-space house translation for physical floor calibration, never a camera correction.
- **Projection and occlusion:** one native ModelScene handles actor perspective and depth. No rear/foreground actor passes, screen-size matching, floor-UV snapping or screen-space position corrections are used. Chair picking uses native projection of its world bounds. Seat facing uses world yaw.
- **Ground:** removed the independent mathematical inverse-camera projection and horizon/seam nudges. A plane homography, adapted from the existing native FloorPoint calculation, is fitted from four actual native projected points each frame *after* the view camera update. The wood presentation samples that world Z=0 mapping. If native projection is unavailable/degenerate, the ground hides and `/fs3d report` records why; no independent perspective fallback is substituted. Strip interpolation remains approximate within each strip, and the texture is not a native depth-writing mesh. Near the projection horizon or beyond the bounded 512-unit presentation extent it yields to sky.
- **Shadows:** legacy layered contact-shadow/cinematic UV freezing code is not loaded or called. There are no experimental screen-space shadow overlays to detach from world positions. This build does not add shadow rendering or certify native cast shadows.

**Single-session acceptance:** confirm a usable house, then rotate the camera all the way around it while moving with WASD. Pitch, zoom and follow the moving player; inspect the table, chair and both NPCs. Watch fixed-size native actors and their world-ground contacts for floating, sliding or a second perspective transform. Sit and stand, then rotate again. `/fs3d report` includes world positions, model scales, coordinate mode and ground registration status. Model API translation conventions, texture registration, occlusion and seat/body alignment still need this real Forever check; numerical tests do not prove visual success.

The existing v0.3 download ZIPs and patch have been refreshed to addon version v0.3.1 and include the complete standalone addon relative to original base `9bc2326f67532c548102caa831b20af2234d6bfe`, including this fix. For an already-applied v0.3 prototype, the integration delta is WorldSpace.lua, Background.lua, Prototype.lua, Interactions.lua, the TOC, Checks.lua and this README. Preserve production rendering unchanged when adopting this adapter.

## Journal and shelf reuse (v0.4)

- `Library.lua` connects native book/shelf hits and collision-checked approach routes to isolated close-up presentation. Book and shelf remain native actors in world XYZ. These modal UI views never change the scene camera, actor scale, world positions, shadows or projection. While a view/transition is active, scene movement and camera input are released; closing/combat cancels presentation and pending approaches.
- `Vendor/AthenaBookObject.lua` is the existing Journal cover controller, with only its cover asset path retargeted to the standalone addon. `Vendor/AthenaBookMotion.lua` and `Vendor/WardenComposition.lua` are unchanged copies. Page turns use the existing page poses/timing/controller over the existing book artwork; this is a small demo manuscript view, not the full production typesetter/library/search/source-history interface. Physical book sequences 148/149 (open) and 146/147 (close) and the .333-second native sequence handoff / 2.6-second room-book transition are adapted from WardenRoomBook. Unsupported sequences leave an explicitly unverified/static prop and are reported.
- `ShelfState.lua` extracts WardenShelfShowcase's existing Validate/Swap functions. The existing owner/history Read/Save methods are deliberately not loaded. Seven-slot state is cloned into an editing copy; Save session commits to local memory and Cancel discards unsaved changes. `SampleCatalogue.lua` selects the first seven existing activity definitions and their two regional mementos. WardenComposition renders stage-5 badge recipes with those mementos in the close-up showcase. No artificial screen-space badge quads are attached to the 3D shelf: it remains a native empty shelf model, and its badge presentation appears in the interaction view. This avoids carrying the production layered shelf's screen-space correction/shadow behavior into the rotating world.
- `Media/Library/` contains byte-identical copies of AthenaBookCovers.tga and Journal3/{OpenBook,Activity01,Stamps01,InkColorized,Keepsakes01}.tga. This is the required six-image subset only.
- `LibraryChecks.lua` exercises UI lifecycle callbacks with call-recording boundaries; it does not render, replace the client, or certify native visuals. The main Checks.lua also tests badge recipes/assets, slot edits, support-aware approach routes, blocked access and the existing page-motion completion.

All demo pages, badge inventory, reader place and saved layout are session-only. A private Lua namespace supplies transient presentation preferences; no SavedVariables are declared, no production addon is required or queried, and no migration, collection, credential or network operation runs. Full real-history Journal integration, physical in-world badge material occlusion and earned-inventory persistence remain outside this isolated test. Picking is projected native bounds, not a mesh/depth-buffer raycast. Actual native appearance, book animation, inside-house access, modal controls and 360-degree alignment still require the single in-game session above.

Latest downloads are in `deliverables/v0.4/`; the changed-files ZIP and patch include the full standalone addon, including the earlier world-space fix, relative to base `9bc2326f67532c548102caa831b20af2234d6bfe`. Production files remain unchanged. Source/vendor provenance and test commands are included so the Pro account can integrate the scene adapter against its newer stabilized build without copying old production database code.

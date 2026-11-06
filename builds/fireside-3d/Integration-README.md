# Fireside 3D — Elwynn candidate 3

Branch: `feature/fireside-3d`. Public production base: `e4cc9f8da008fd065d933e6d142dde854108d53a`. Main and CurseForge are unchanged.

## Install

Close WoW and retain your normal WTF backup. Extract **Fireside-3D-candidate3-overlay.zip** into `Interface/AddOns/`, replacing public code and the `Fireside3DAssets` catalog. Use the exact base above or candidate 1/2 installed with that same base media. Retain the base's approximately 1.4 GB media library; the overlay includes code, the lazy catalog, existing recovery code and the grass tile. Do not overlay a later stability build; integrate the source changes against it instead. Do not install the standalone prototype alongside it.

The private development addon is **not included**. Keep it local. Public adapters extend its existing editor when installed; no private implementation, archive, credentials or configuration is packaged or committed.

Open `/fireside`. WASD moves your character over the scene; right-drag rotates/pitches and wheel zooms. Open Menu retains the normal services. The My Home action walks toward the home entrance in the same world.

## Only Elwynn buildings

| Requested building | FileDataID | Actual world asset |
| --- | --- | --- |
| Player home / interior target: Goldshire Inn | 106851 | `world/wmo/azeroth/buildings/goldshireinn/goldshireinn.wmo` |
| Elwynn farmhouse | 106965 | `world/wmo/azeroth/buildings/human_farm/farm.wmo` |
| Goldshire blacksmith | 106848 | `world/wmo/azeroth/buildings/goldshireblacksmith/goldshireblacksmith.wmo` |
| Elwynn stables | 107232 | `world/wmo/azeroth/buildings/stable/stable.wmo` |

All four earlier Arathi/swamp selections are removed. These are Classic Elwynn world-building references, not retail housing. Goldshire Inn's actual game-world asset contains an interior. **It is not yet established that Forever's UI ModelScene can render that WMO and its interior.** Public listfile resolution verifies only the IDs/paths. A successful API call or loaded bounding box is not visual certification. All four entries remain `ELWYNN_WMO_RENDER_UNVERIFIED` in the catalog and scene report.

This is a native Elwynn WMO test build, not a claim of a finished or verified walkable inn. It uses the existing `SetModelByFileID` path; no WMO extraction/conversion, custom building mesh or replacement renderer is introduced. There is no fallback to the rejected huts. If ModelScene cannot load the inn, actual interior furnishing remains blocked; resolve that native capability before treating the home as usable.

The scene shows the home load status. Native failures and missing-model cubes cannot become a giant house-shaped box: recognized placeholders/mismatched model identities are rejected. Until the home has actual native bounds, its table, book, chair and showcase remain hidden and interior interactions are unavailable. An explicitly failed building is omitted from collision, allowing the rest of the demo to continue. Pending bounds pause walking until loading resolves. The report lists each building's requested ID, loading/error status and the unverified interior status.

## Interior placement

The home retains the real animated Journal book/table, chair and earned-badge/memento showcase. They have provisional placements around the inn's central ground-floor area. Their final position, orientation, doorway and floor alignment need the first native interior pass. Do not assume the WMO's lowest bounding-box point is its actual ground-floor walking surface.

Use the existing editor's object, position, height, rotation and collider controls after confirming the inn is visibly rendered. The home still uses the prototype's explicit bounds-based wall/door shell and flat world floor. It does not implement the inn's internal wall mesh, stairs, basement/upper-floor navigation or camera-wall collision. A rendered inn plus an approximate outer collider is not mesh-perfect collision. The other three buildings remain environmental structures with solid bounds collision.

The new `fireside-3d-elwynn` layout slot starts this arrangement independently of old candidate/hut placements. Previous 3D and 2.5D saved layouts remain intact; no migration or overwrite occurs. Keep private editor exports local.

## Right-drag and editor camera

The scene input now explicitly registers right-button press/release **and right-button dragging**, with separate left-click interaction. It stacks above stale scene input frames and stops propagation to WoW's world camera. A captured right drag can leave the floor rectangle and ends on right-button release, drag-stop, hide, combat or a blocking form. Left-button release does not cancel a right drag. Mouse state is polled so a missed mouse-up cannot strand the camera.

Open the existing editor with local test mode enabled. Older Study/Fields launch buttons target this single world. Camera controls remain:

- **WASD:** fly/strafe; **Q/E:** down/up.
- **Right-drag:** look through 360 degrees and pitch up/down.
- **Shift:** three times faster; **wheel:** dolly.
- **Reset camera:** return to the character's follow viewpoint.

Keep the pointer over the scene to begin a drag or fly with keys. Forms, typing, object dragging and combat release camera movement. The existing left-drag object handle remains separate. Editor flight does not move/resize the character, change collision, save a layout transform or publish Live movement. NPCs remain paused during editing and resume on close. Closing the editor restores character follow. Existing test-mode, trust and Live editing guards remain authoritative.

## Catalog and retained systems

The lazy catalog contains four explicitly unverified Elwynn WMO entries and seven existing Classic/Forever prop references. Its source is `tools/fireside3d/elwynn-assets.csv`; regenerate with:

```
python3 tools/fireside3d/build_classic_catalog.py --listfile /path/to/community-listfile.csv
```

Only those four WMO IDs/zone/status combinations are admitted as candidates. They are not classified as compatible/verified M2 props. The broader supplied research CSV remains offline and is not loaded by the client. Existing Forever furniture remains available in the editor. Selecting a candidate fills its real model ID in the existing form. The Dalaran showcase shelf remains the base's existing Forever reference with calibrated badge ledges; it is not a building or labeled original Classic.

One native depth buffer holds actors in camera-independent world XYZ. Painted-depth size corrections and old scene instances/travel remain inactive. Ground, paths and contact shadows are projected world-plane presentation. Real Journal permissions/history, earned inventory, reader place and badge save paths remain authoritative. No synthetic history, grants, SavedVariables declaration, schema, database root or credential flow is added.

Aether Live retains protocol **2**, scene `square` / wire code `a`, certificate trust, native sender binding, appearance reconstruction, existing coalesced movement/recovery and eight remote slots. Both clients must use **candidate 3**: the existing geometry digest changes for the Elwynn buildings, bounds and NPC paths. NPCs keep the base's deterministic schedule. Storage, recovery, collectors and authentication/transport source match the recorded base.

## Native test session

1. Open `/fireside`; test right-drag before and after building loading. Check orbit/pitch, wheel, full sky and stable actor alignment. Verify left clicks still move/interact, releasing right drag outside the scene stops it, and Open Menu remains clickable.
2. Inspect each Elwynn building. **First verify that Goldshire Inn visibly renders both outside and inside.** A blank viewport, placeholder or only accepted bounds is a failure. Read the load message and export the scene report; do not proceed as if an interior exists when it does not.
3. With the private editor installed locally, fly inside the visible inn using WASD/Q/E/right-drag. Inspect the true doorway and ground floor; align the home and housing objects with the existing fields and collider controls. Test object dragging, typing in forms, camera Reset/Close and NPC pause/resume. Do not certify stair/internal-wall collision that this build does not implement.
4. Once the home is visibly aligned, test walking through the entrance, chair sit/stand, your real Journal and the earned showcase. Empty history/inventory stays empty; check reopening and normal saves. If inn rendering or floor alignment fails, the interior acceptance test remains blocked.
5. Connect two consenting clients on candidate 3 through the existing Live controls; check geometry, appearance, movement, seating and reconnect. Leave Live before editing. Older candidates/legacy geometry must be incompatible.

## Checks and integration

```
lua5.1 tools/fireside3d/checks.lua
lua5.1 tools/fireside3d/lifecycle.lua
lua5.1 tools/fireside3d/editor_camera.lua
```

Checks cover Elwynn-only selection, candidate-vs-verified status, missing-home furniture/placeholder handling, logical collision, layout isolation, camera-independent placement, retained Live codec/coalescing, one-viewport lifecycle, registered right-drag and click separation, stale-frame stacking, captured-drag release, editor movement/input guards and NPC pause/resume. They record Lua/API boundaries; they do not render WoW models or qualify actual mouse dispatch in Forever. Native interior and two-client checks remain pending.

The changed-files ZIP and patch contain the full integration against `e4cc9f8`, including candidate 3. Reconcile the scene-gated changes against newer stability work rather than overwriting newer authentication/storage/network files. Review before merging or publishing a production release.

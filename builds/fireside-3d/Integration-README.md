# Fireside 3D — New Home candidate 2

Branch: `feature/fireside-3d`. Production base: `e4cc9f8da008fd065d933e6d142dde854108d53a` (the updated hotfix with Aether Live). Main and CurseForge are unchanged.

## Install

Close WoW and keep your normal closed-client WTF backup. Install the exact public base above, then extract **Fireside-3D-candidate2-overlay.zip** into `Interface/AddOns/`, allowing replacement of the public addon code and the `Fireside3DAssets` catalog. You can also apply this overlay to candidate 1 when it uses that same base media. Do not overlay a later stability build; integrate the source changes against it instead. The overlay includes public Lua/XML/TOC code, the optional catalog, existing recovery code and the grass tile. Retain the base's approximately 1.4 GB media library. Do not install the standalone prototype alongside this build.

The private development addon is **not included**. Keep it local. Its existing editor is optional for gameplay; public adapters extend that editor when installed. No private archive, implementation, credentials or configuration is committed or packaged.

Open `/fireside`. WASD moves your character while the pointer is over the world, right-drag rotates/pitches, and wheel zooms. Menus, typing, editing and combat release player input. The My Home action walks to the home entrance within the same world. Open Menu retains the normal Journal, Atlas, Agora, settings and other services.

## Four different Classic house models

| Building | FileDataID | Original model path |
| --- | --- | --- |
| Player home: Swamp water hut 1 | 190430 | `world/azeroth/swamposorrow/passivedoodads/waterhuts/waterhut01.m2` |
| West: Arathi farmhouse 1 | 203656 | `world/lordaeron/arathi/passivedoodads/farmhouses/arathifarmhouse01.m2` |
| East: Arathi farmhouse 2 | 203657 | `world/lordaeron/arathi/passivedoodads/farmhouses/arathifarmhouse02.m2` |
| South: Swamp water hut 2 | 190431 | `world/azeroth/swamposorrow/passivedoodads/waterhuts/waterhut02.m2` |

These are four distinct original Classic-era M2 references. The new selections add two farmhouse models and a different hut, retaining the original tested home. Their ID/path pairs were resolved against the public wowdev listfile. This verifies the reference, **not installation or visible rendering in the running Forever client**. The three newly selected models still need a native check for availability, appearance, dimensions and openings. No WMO root or retail housing model is requested by these four buildings. There is no silent substitution of the original hut for a missing model.

Only the player home has the explicit wall/door shell and interactive interior. The other three buildings have solid bounds-based collision. House rotation, size and collider alignment remain adjustable in the existing editor. The original hut/collider mismatch is not claimed fixed by selecting the other models; inspect and align it natively. Stairs, mesh navigation, camera-wall collision and terrain elevation are outside this prototype.

Pending house bounds pause player movement until loading resolves. A model explicitly reported failed or hidden is omitted from collision rather than freezing the entire demo; its native error remains in the scene report. It is not replaced with an invisible building collider or another hut.

## Scene editor free camera

Open the existing editor with local test mode enabled. Its older Study/Fields launch buttons now target the single 3D world. The editor opens over the wide scene. Fly-camera controls appear at the top left:

- **W/S:** fly forward/back along the view direction.
- **A/D:** strafe left/right.
- **Q/E:** lower/raise the camera.
- **Right-drag:** look around through 360 degrees and pitch up/down.
- **Shift:** move three times faster; **wheel:** dolly forward/back.
- **Reset camera:** return the editor view to the character's normal follow viewpoint.

Keep the pointer over the scene for movement. Typing, forms, object dragging, combat and leaving the viewport release camera input. Left-dragging the existing object handle still edits the selected object. Camera flight passes through walls and does not move the character, alter colliders/scales, save a layout transform or publish player movement. Camera position is transient; closing the editor restores character follow. The existing editor's NPC pause remains active and normal NPC updates resume on close. Trust, local test-mode and Live editing guards remain in the existing editor.

## Compatible prop catalog

The lazy `Fireside3DAssets` addon now contains **11 explicit M2 references**: ten Classic-era models plus the existing Forever earned-badge shelf. The broader retail/expansion WMO research entries are removed from the runtime catalog. The pre-existing Forever object library remains available. New references are merged into the existing editor's category, search and selection lookup; choosing a farmhouse fills the actual model fields.

The Dalaran shelf (242995) is retained because the public production showcase already identifies it as an installed Forever mesh and calibrates its badge ledges. It is an existing Forever reference, not labeled original Classic or newly native-certified. Keeping it preserves the real earned showcase. Other placed furniture uses the existing Classic table, chair, animated book, Elwynn fire and fir tree references.

`classic-assets.csv` is the explicit source for the new catalog. Rebuild it with:

```
python3 tools/fireside3d/build_classic_catalog.py --listfile /path/to/community-listfile.csv
```

The supplied broader `research-candidates.csv` and original research script remain offline research inputs under `tools/fireside3d/`. They are not loaded by the client or offered as compatible props. Listfile resolution and source metadata never count as a render test.

## Retained integration

One native ModelScene/depth buffer holds buildings, furniture, your character, existing NPCs and Live peers in a fixed world XYZ basis. Placement has no painted-depth scale or floor-UV correction. Ground, paths and contact shadows project world planes through the actual camera; they are not native mesh terrain or physical shadow maps. Fields, Study and old Town instances/travel remain inactive. Legacy source/resources remain recoverable, and the `fireside-3d` layout slot preserves old 2.5D layouts without migration. Existing saved 3D overrides can still affect the revised buildings; inspect them with the editor before resetting an object.

The home book and shelf use existing collision-checked approach routes, real Journal/history permissions and actual earned inventory. Existing save, reader-place and badge recipe behavior remains authoritative. No synthetic pages, rewards or grants are shipped.

Aether Live retains the base's protocol **2**, certificate/session trust, native sender binding, P2P transport, appearance reconstruction, coalesced movement channel, recovery and eight remote actor slots. Scene `square` keeps wire code `a`. The existing geometry digest includes the revised buildings, bounds, coordinate mode, doorway and NPC world paths, so **both clients must run candidate 2**; candidate 1 geometry is incompatible. Manual player updates keep the existing six-Hz coalesced M cadence and immediate final idle update. Camera flight never enters that state. NPCs retain the existing deterministic clock/path routine with world points, not a new authority or packet system.

Storage, recovery, collectors, authentication and transport source files match the recorded base. No SavedVariables declaration, schema, migration, database root or credential flow is added.

## One native test session

1. Open `/fireside` and inspect **four different models**: the two Arathi farmhouses and two water huts. Check the full sky, ground, paths and gathering area. Report any missing/placeholder building with its FileDataID.
2. Move your character while rotating 360 degrees, pitching and zooming. Check stable world size, floor contacts, shadows and colliders. Open/close normal content, type in chat and enter/leave combat to verify input release.
3. Enter the player home through the negative-Y entrance; inspect the wall/door alignment. Sit/stand in its chair. Open your real Journal, use the page/cover controls and return. Inspect/edit earned badges/mementos; empty inventories stay empty. Reopen to check the existing save path.
4. With the private editor installed locally, open it from its existing launcher. Fly away from the character, move vertically, rotate fully around all four buildings and dolly inside the home. Verify the character remains in place, NPCs pause, object handles still place correctly, forms accept typing, and Reset/Close restores the expected camera. Browse Houses, select an Arathi farmhouse and verify its ID fills correctly. Keep private exports local.
5. Connect a second client using the existing Aether controls and explicit Live participation. Both clients must use candidate 2. Compare geometry revision; inspect movement, appearance, NPC paths, seating and disconnect/reconnect. A candidate 1 or legacy-layout client must be incompatible. Leave Live before editing, as the existing guard requires.

The earlier prototype mechanics were user-reported successful. The revised three house models, editor camera in the private editor, expanded native rendering and two-client delivery have **not** been visually qualified in Codex Cloud. Code/call-recording checks do not certify those behaviors.

## Automated checks and integration

Run from repository root with Lua 5.1:

```
lua5.1 tools/fireside3d/checks.lua
lua5.1 tools/fireside3d/lifecycle.lua
lua5.1 tools/fireside3d/editor_camera.lua
```

Checks cover four distinct model selections, one native viewport, real Journal laziness, doorway/rotated collision, camera-independent actor placement, Live codec/geometry/coalescing, Classic catalog filtering/selection, editor launch mapping, fly/strafe/height/look/dolly, camera reset/follow restoration, input guards, player-state isolation and NPC pause/resume. Packaging uses explicit public Git paths and checks private-reference exclusion and ZIP integrity. Lua syntax, TOC paths and protected-source bytes are checked separately.

The changed-files ZIP and patch contain the full integration against `e4cc9f8`, including candidate 2. For newer stability builds, reconcile the scene-gated realm, camera, catalogue, travel, layer, Live presentation and TOC changes; do not replace newer authentication/storage/network files with prototype copies. Review before merging or publishing a production release.

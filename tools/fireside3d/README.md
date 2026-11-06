# Fireside 3D — Simple farmhouse test candidate 5

Branch: `feature/fireside-3d`. Public production base: `e4cc9f8da008fd065d933e6d142dde854108d53a`. Main and production releases are unchanged.

Candidate 3 crashed the real client during startup with an access violation. Its four new Elwynn WMO requests are suspects; the screenshots do not identify a specific model or native function. This build removes buildings from the automatic scene and leaves all four available for manual editor spawning, as requested. It adds no new quarantine, model-ID block or replacement building. The existing native renderer/loader source is unchanged.

## Install

With WoW closed, extract **Fireside-3D-candidate5-overlay.zip** into `Interface/AddOns/`, replacing public code and the optional `Fireside3DAssets` catalog. Retain the exact base's existing media. It can overlay candidates 1–4 using that same base; do not apply it over a later stability build. It contains public code, existing recovery code, the lazy catalog and the grass tile rather than duplicating the approximately 1.4 GB base media library.

Open `/fireside`. The default scene has **zero building model requests**. Ground, sky, existing M2 props, your character, NPCs, real Journal, chair, earned shelf, player input and the editor fly camera remain available. Housing objects stay visible in the open scene. My Home walks toward the home site without requiring a building. The interior itself remains unresolved.

The private development/editor addon is not included; keep the existing local installation. No private implementation, archive, credentials or configuration is committed or packaged. No crash log is published.

The `fireside-3d-elwynn-manual` layout slot is retained from candidate 4 and keeps pre-diagnostic placements separate. Earlier layouts and SavedVariables remain intact; no migration or deletion occurs. If you explicitly save a manual building placement in the new slot, the existing editor may reload it normally. Leave these isolation tests unsaved to retain an empty-building startup.

## Preferred small-home candidate

The next selected test is **Elwynn farmhouse, FileDataID 106965**, root `world/wmo/azeroth/buildings/human_farm/farm.wmo`. It is now first in the lazy catalog and available through **Add farmhouse test** on the existing editor camera toolbar. Open the editor, click that button once, then inspect the result. The shortcut reuses the existing AddObject method and starts the preview as decoration, so a full-bounds collider does not block interior inspection. Normal placement/collision controls remain in the existing object form.

The requested layout is one storey, one room and one entrance. **Those properties, and the absence of a basement, still need visual verification.** The public listfile has two numbered group references for this farmhouse versus twelve for Goldshire Inn. This is a simpler structural candidate, not a floor-plan proof or native-render certification. It remains a WMO; simplifying the building does not establish or fix the cause of the earlier access violation.

The package includes **FIRESIDE-3D-BUILDING-SELECTION.md** with exact paths, group-reference evidence, snapshot hash, limitations and the layout acceptance checklist. The source is `tools/fireside3d/building-selection.md`.

A successful model request is only the first step. Walk/fly around it, inspect inside, count the actual entrances and rooms, and check for stairs/cellar access before accepting it as the housing shell. If it has a loft, extra room or another doorway, report that as a layout mismatch even if it renders successfully. Keep the test unsaved.

## Spawn one building at a time

Use the existing editor's **Add object → Elwynn buildings** category. All four choices and actual native loading remain enabled:

| Model | FileDataID | Actual asset |
| --- | --- | --- |
| Goldshire Inn | 106851 | `world/wmo/azeroth/buildings/goldshireinn/goldshireinn.wmo` |
| Elwynn farmhouse | 106965 | `world/wmo/azeroth/buildings/human_farm/farm.wmo` |
| Goldshire blacksmith | 106848 | `world/wmo/azeroth/buildings/goldshireblacksmith/goldshireblacksmith.wmo` |
| Elwynn stables | 107232 | `world/wmo/azeroth/buildings/stable/stable.wmo` |

1. First confirm that the scene opens without a building. If that still crashes, record it as a baseline failure; the four automatic building requests are absent.
2. Select one building and note its name/ID before clicking Add. Observe whether Add returns, a model becomes visible, and a crash happens immediately or after a delay. A farmhouse-first order is convenient, but the build imposes no order or one-object limit.
3. If the client remains running, inspect the building from outside/inside with the editor camera. Remove that object before trying the next one. Keep the layout unsaved during isolation.
4. If it crashes, capture the selected name/ID and the **Show log file** crash text. Share that log privately for diagnosis; this build does not upload or commit it. Restart with the empty unsaved scene for the next test.

No automatic fallback, retest timer or bulk-spawn action is added. The original editor's test-mode, consent, Live editing and object limits still apply. Original native renderer policies are retained; no new policy excludes these four IDs.

## Load diagnostics

Before the existing native prop loader runs, the public scene adapter records/prints the selected name, FileDataID, editor slot and a session test number. It records whether the loader returned, whether native bounds became ready, or whether a normal native error was reported. The bottom notice shows the latest attempt; the existing scene report contains all currently placed Elwynn instances and that attempt's status.

These diagnostics are transient Lua state and chat messages. A fatal native crash can lose the in-memory trace, so note the selected ID before Add and retain the real crash log. A returned API request or accepted bounds is not a visible render/interior pass. None of the candidates is marked verified by this build.

## Existing controls and integration

Player: WASD moves over the scene, right-drag orbits/pitches, wheel zooms. Editor: WASD flies/strafes, Q/E lowers/raises, right-drag looks, Shift moves faster, wheel dollies and Reset restores the character follow viewpoint. Captured right-drag, release handling, left-click separation, scene input stacking, focus/form/combat guards and NPC pause/resume remain from candidate 3.

The real Journal, chair and earned shelf work in the open test scene without a house. Their normal permissions, inventory and saved reader/showcase state remain authoritative. No synthetic history or grants are added. Adding a custom building uses the existing editor's normal collision settings; a visually loaded inn does not establish stair/internal-wall navigation or an enterable house collider. This is first a model-isolation test.

Aether Live retains protocol 2, scene `square` / wire code `a`, trust, transport, appearance, existing movement/coalescing/recovery and session limits. Candidate 5 keeps candidate 4's world geometry; use matching current builds when reproducing tests. Use the established workflow of leaving Live before editing. Storage, recovery, collectors, authentication, transport and native renderer source match the recorded public base.

The preferred-test metadata records the requested layout and `layoutVerified=false`; the catalog builder also verifies the two farmhouse group references. The lazy catalog remains sourced from `tools/fireside3d/elwynn-assets.csv`. Its four WMO entries retain unverified-candidate status; seven existing M2 prop references and the pre-existing Forever object library remain available. No broader retail research is added to runtime browsing.

## Checks and integration

```
lua5.1 tools/fireside3d/checks.lua
lua5.1 tools/fireside3d/lifecycle.lua
lua5.1 tools/fireside3d/editor_camera.lua
```

Checks also cover the preferred farmhouse shortcut, reuse of existing editor AddObject, no spawn on opening the editor, and active-editor/combat guards. Checks verify zero default building requests in the real realm construction path, all four editor selections retained, manual native requests still allowed, per-model diagnostics, active housing objects, fresh layout isolation, unchanged Live codec/coalescing, collision/placement, registered camera input and editor pause/focus guards. Syntax, TOC paths, protected-source hashes and package integrity/private-reference exclusion are also checked. These do not identify the crashing native instruction or certify a crash-free Forever session.

The changed-files ZIP and patch contain the complete public integration against `e4cc9f8`, including this diagnostic change. Review against newer stability work before integrating; no merge or production publication is performed.

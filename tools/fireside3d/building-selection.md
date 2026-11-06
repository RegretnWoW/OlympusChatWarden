# Simple Elwynn home selection — candidate 5

Preferred next test: **Elwynn farmhouse — FileDataID 106965**.

Root: `world/wmo/azeroth/buildings/human_farm/farm.wmo`.

The requested acceptance criteria are one storey, one enclosed room, one entrance and no basement. They are **requirements to check**, not verified properties of this file. The farmhouse is a smaller residential candidate than Goldshire Inn and a better next isolation target. It remains a WMO and may share the same UI-rendering problem.

## What the public listfile establishes

| Asset family | Root FileDataID | Listed numbered group files | Interpretation |
| --- | --- | --- | --- |
| Human farm | 106965 | 2: 106966, 106967 | Preferred small-house candidate; layout must be inspected |
| Goldshire blacksmith | 106848 | 2: 106849, 106850 | Small workshop alternative, retained in the editor |
| Elwynn stable | 107232 | 1: 107233 | Barn/stall layout, not established as one enclosed residential room |
| Goldshire Inn | 106851 | 12 | Larger structure; retained for manual isolation, not the preferred home |
| Human two-story family | 106973 | 6 | Distinct model family, not selected for this test |

Farm group references are `world/wmo/azeroth/buildings/human_farm/farm_000.wmo` and `farm_001.wmo`. They are parts of the root WMO, not standalone buildings to spawn. The catalog builder checks those two mappings before generating the preferred-test metadata.

Source: public wowdev/wow-listfile repository, https://github.com/wowdev/wow-listfile . The resolved local listfile snapshot has SHA-256 `3f12a5c52e81d01fd1a1c97baf0387d8109e27633e953c6af93630cb9825d0f2`.

A listfile has paths/IDs, not geometry, floor plans or installation proof. Numbered group-file count is a structural comparison only: **two groups do not prove one room, one entrance or one floor**. These are current public-listfile references rather than a manifest of the user's Forever installation. No native model mesh or floor-plan inspection was available in this environment, so those criteria and the lack of a basement remain unverified.

## How candidate 5 makes this test concrete

- No buildings load by default; all four previous choices remain manually available.
- Farmhouse is first in the lazy catalog and searchable by the desired layout.
- The existing editor camera toolbar has **Add farmhouse test**, which calls the existing editor's AddObject for 106965 at height 7. It starts as decoration so a full-bounds collider cannot prevent visual interior inspection. The original editor form still offers the normal collision settings.
- Existing model-ID/load diagnostics identify the requested root; no alternate renderer, conversion, model quarantine or automatic retest is introduced.

After a successful visible render, inspect the building from all sides and from inside. Confirm the ground floor, count the actual entrances/rooms, and check for stairs or a cellar before accepting it as the housing shell. If it renders but fails the requested layout, report that separately from a loader crash. Keep the test unsaved and share any crash log privately.

A basement is ordinary 3D geometry. The reported access violation does not establish the basement as the cause, nor does a simpler model guarantee a fix. The native crash log and individual tests are still needed to distinguish an asset-specific failure from WMO support in the UI renderer.

# Fireside 3D — Single M2 tent test, candidate 6

One new manual test: **Night Elf single tent 01, FileDataID 328178**.

- Actual model path: `world/generic/nightelf/passive doodads/tent/nightelfsingletent01.m2`.
- Format: **M2**, not WMO or converted MDX.
- Reference: resolved ID/path in the public wowdev verified listfile.
- Forever installation and visible rendering: **not verified** in Cloud.

This older stock M2 is a better match for Fireside's existing ModelSceneActor loading method than the WMO buildings that were being tested. That reduces the format mismatch; it cannot guarantee native crash safety. This is an alternative tent, not a claimed resolution of Camp Tent item 279978 or game object 528996.

## Install and test

With WoW closed, extract **Fireside-3D-candidate6-overlay.zip** into `Interface/AddOns/`, replacing public code and `Fireside3DAssets`. Retain the existing media from exact public base `e4cc9f8da008fd065d933e6d142dde854108d53a`. It can overlay previous candidates using that same base. The private editor addon is not included; retain your local copy.

Open `/fireside`, open the existing editor, then click **Add tent test** on the camera toolbar. This calls the existing editor's AddObject with FileDataID 328178, a 3.2-unit preview height and decoration collision. No tent or building loads automatically on a clean layout. The entry is also searchable by `328178` or `Night Elf tent` under Shelters.

Inspect whether it visibly renders, then rotate/fly around it. Leave the test unsaved until the result is known; remove it before testing another model. Existing private saved placements can still reload normally if explicitly saved. If a native crash occurs, retain the selected ID and crash log privately.

Existing movement, free camera, NPCs, Journal, chair, earned shelf, ground, sky and Aether Live are preserved. The previous four editor building entries remain available; no new quarantine, native loader change, automatic retry, scanner, viewer or renderer is introduced. Candidate 6 retains the previous physical world and layout slot.

Automated checks cover the manual button/editor path and guards, no startup spawning, exact metadata, existing native-call path, input/camera and Live behavior. Lua syntax, TOC references, native/auth/storage source hashes and package privacy/integrity are checked. These are not native Forever rendering or crash-safety certification.

Private files, credentials, crash logs and the private editor implementation remain excluded from GitHub and the package. Main and production releases are unchanged. The changed-files ZIP and patch include the complete public integration against the recorded base.

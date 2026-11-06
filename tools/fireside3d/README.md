# Fireside 3D — Forest shelter test, candidate 7

New preferred candidate: **Furbolg forest tent — FileDataID 202016**, a stock M2 reference at:

`world/kalimdor/kalidar/passivedoodads/furbolgtent/furbolgtent.m2`

This is a rustic forest-creature shelter candidate rather than Night Elf architecture. Its exact path/ID resolves in the public verified listfile. **Its visible entrance, enclosure and rendering in Forever still need a client check.** The requested open entrance is not recorded as verified merely from the asset name.

[Reference-image search: WoW Teldrassil furbolg tent](https://www.google.com/search?tbm=isch&q=WoW+Teldrassil+furbolg+tent). This is a style-reference search, not a verified preview of FileDataID 202016.

## Install and test

With WoW closed, extract **Fireside-3D-candidate7-overlay.zip** into `Interface/AddOns/`, replacing public code/catalog. Retain the exact public base e4cc9f8da008fd065d933e6d142dde854108d53a media and the existing local private editor addon. It can overlay earlier candidates using that same base. No private addon files are included.

Open `/fireside`, open the existing editor and click **Add forest tent**. It uses the existing AddObject/native M2 loader with a 3.2-unit preview height and decoration collision. The same entry is searchable by 202016, Furbolg or forest under Shelters. No tent/building is loaded automatically on a clean saved layout.

Check the visible front opening from outside and inside. Preview collision is off: walking through a surface is not proof that the mesh has a doorway. If the shape is closed or unsuitable, remove it without saving and report that as a model/style mismatch. The existing editor's scale, rotation and collision controls remain available. Native crash safety cannot be guaranteed by Lua checks.

The previous Night Elf tent, **328178**, is retained and marked **USER_REPORTED_NATIVE_RENDER / reported working** following the user's successful test. That report confirms rendering for that model, not an opening, new model availability or general crash safety. The new Furbolg tent remains **M2_RENDER_UNVERIFIED**. Earlier manual building choices remain; there are no new model blocks or spawn loops.

Movement, camera, NPCs, real Journal/chair/earned showcase, multiplayer, ground and sky remain unchanged. The physical world and layout slot are retained. Tests cover the new selection/manual shortcut, the reported-working distinction, no startup loads, native request path, camera/input and existing Live behavior. Syntax, protected-source hashes and package integrity/privacy checks pass; the new model needs its native test.

Main and production releases remain unchanged. Private source, credentials and crash logs are excluded. The changed-files ZIP and patch contain the complete public integration against the recorded base.

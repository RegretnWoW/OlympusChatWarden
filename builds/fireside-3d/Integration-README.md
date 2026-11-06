# Fireside 3D — New Home candidate

Branch: `feature/fireside-3d`. Authoritative production base: `e4cc9f8da008fd065d933e6d142dde854108d53a` (the updated hotfix with Aether Live). No merge into main or CurseForge publication is performed.

## Install the single candidate

Close WoW and keep your normal closed-client WTF backup. Install the exact public base build identified above first, then extract **Fireside-3D-candidate1-overlay.zip** into `Interface/AddOns/`, allowing replacement of the public addon code. It contains the complete public Lua/XML/TOC code, the optional candidate catalog, the existing recovery addon code, and the new grass tile. Do not overlay a later stability build; integrate the source changes against that newer build instead. Existing production media must remain installed: this overlay deliberately does not duplicate the approximately 1.4 GB media library. Do not install the old standalone prototype alongside it for this test.

The private development addon is **not included**. Keep any private development installation separate and local. The existing editor is optional for gameplay; the candidate extends its existing browser when that editor is installed. No private archive, credential, issuer configuration or private implementation is committed or packaged.

Open `/fireside`. The default view is the new neighborhood; Open Menu retains Journal, Atlas, Agora, settings and other existing services. WASD moves while the pointer is on the world, right-drag rotates/pitches, and wheel zooms. Moving/typing outside that surface, menus, modal views, editing and combat release world input. The Oasis navigation action walks toward the home entrance in the same world; it no longer changes environments.

## What changed

- Exactly one primary world instance and one native ModelScene/depth buffer. Five buildings reuse the prototype's default water-hut model, FileDataID **190430**. This is five instances of the reported working model, not five newly certified house assets. One home contains the real Journal, chair and real earned-badge/memento shelf. A small fire/gathering area, trees, grass, projected paths and the production full-sky artwork complete the compact layout.
- The prototype's world XYZ placement, camera and input are adapted into the current realm. Fixed model pivots/native API conversion remain; painted-depth scale curves, floor-UV relocation and multi-pass actor occlusion are not applied to this scene. Ground, path decals and contact shadows are projected world-plane presentation, not native triangle terrain or physical shadow maps. No custom M2/WMO geometry or extraction pipeline is introduced.
- Fields, Study and the old Town are not instantiated. The old definition/source files remain recoverable and shared resources are retained. The old scene travel links and cinematic are inactive in this candidate. Layout editing uses a distinct `fireside-3d` layout slot, preserving existing edited 2.5D layouts without migration.
- Book and shelf clicks use collision-checked approach routes, then open the existing production Journal and earned showcase. History permissions, empty-history behavior, earned inventory checks, saved reader place, badge recipes and the existing cosmetic save path remain authoritative. No synthetic pages/badges or test entitlement grants are shipped in this world.
- The supplied research CSV is resolved into a separate **load-on-demand** `Fireside3DAssets` addon: 40 metadata rows, not a mandatory startup catalog. Existing editor search can match names, categories, paths and FileDataIDs. WMO entries remain untested candidates; a resolved ID or successful bounds load does not certify visible rendering/interior access. The original index-building Python tool and CSV are retained under this directory; no private editor code is included.

## Aether Live integration

Uses the updated base's existing certificate/session trust, native sender binding, P2P transport, appearance reconstruction, coalesced movement channel, connection recovery and eight remote actor slots. Wire protocol remains **2** and scene `square` retains wire code `a`. The shipped geometry digest now includes the neighborhood's props, world bounds, coordinate mode, home-door settings and NPC world paths, so legacy layouts are incompatible through the existing revision check.

WASD position updates use the existing M state at a six-Hz coalesced cadence, with an immediate final idle update. Only already-validated zero-duration movement states receive scene-specific render interpolation; authentication and geometry rejection still run in the existing Live controller. Canonical NPCs use the existing deterministic clock/path routine with world points instead of painted UV anchors. As in the base, this is not newly authoritative/packet-synchronized contested NPC gameplay.

Storage, recovery, collectors, authentication and transport files are unchanged from the base. Normal existing features may save their normal preferences; no new database root, SavedVariables declaration, schema, migration, backup behavior or credential flow is added.

## One real-client test session

1. Open `/fireside`: confirm one neighborhood, five hut instances, full sky/ground/paths, the gathering area and your character. No old room/travel selection should appear.
2. Move with WASD while rotating 360 degrees, pitching and zooming. Check native object size, floor contacts, world-aligned shadows/colliders and camera follow. Open a normal content tab and return to the world; type in chat and enter/leave combat to check focus release.
3. Enter the home through its negative-Y entrance. The home uses an explicit bounds-based wall/door shell. **The hut/collider mismatch reported in the prototype is not a claim of mesh-perfect collision**; use the existing editor's collider/rotation controls for native alignment and report a mismatch. The four other houses have solid building bounds. No stairs, terrain elevation, camera-wall collision or native mesh navigation is implemented.
4. Click the home chair, sit and stand. Click the book and confirm your permitted real Journal/empty-history message, page/cover controls and return to world. Click the shelf and inspect/edit only actually earned badges/mementos; empty inventory must remain empty. Reopen to verify the existing cosmetic save path.
5. Using the existing Aether controls and explicit Live participation, connect a second client on this **same candidate**, compare shared geometry revision, move both characters, inspect appearance/NPC routines and sit/stand. Check disconnect/reconnect through the existing controls. An old-layout client must report incompatible geometry; no trust/consent requirement should be bypassed.
6. With the private editor already installed locally, browse the optional model candidates, search an ID/category and try a preview/placement through the existing controls. Leave Live before editing, as required by the existing guard. Do not mark WMO candidates verified without actually viewing the result. Keep private exports local.

The prototype mechanics were reported successful by the user. This expanded integration has **not** been visually or two-client qualified in Codex Cloud. Call-recorded tests do not establish native rendering, model availability, collision fit, real-history UI behavior or multiplayer delivery. Supply one combined report from the above session; no intermediate checkpoint builds are requested.

## Automated checks and integration

Run from repository root with Lua 5.1:

```
lua5.1 tools/fireside3d/checks.lua
lua5.1 tools/fireside3d/lifecycle.lua
```

The checks cover room registration, one-viewport construction with retained canonical/Live/shelf wrappers, no old instances/links, lazy Journal/catalog, world transforms, rotated home collision, Live-slot budget, shipped protocol-2 codec/revision handling, WASD coalescing/stop, floor decal clipping and validated-target interpolation. Full Lua syntax, manifest dependencies, artifact integrity, private-file exclusion and protected-source hashes are also checked during packaging.

For the Pro account: review the PR against the recorded hotfix base. Adopt the new `World3D/` modules, the new tile and the load-on-demand catalog, then reconcile the small scene-gated changes in the realm, reading camera, room catalogue, travel, layer staging, Live world presentation and TOC. Do not replace the newer authoritative authentication/storage/network files with prototype copies. The candidate is a graphical integration branch, not a new data or multiplayer architecture.

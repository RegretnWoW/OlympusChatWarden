# Fireside 3D — Forest camp, candidate 8

## Install

With WoW closed, extract **Fireside-3D-candidate8-overlay.zip** into `Interface/AddOns/`, replacing the public code and catalog. Keep the media from public base **e4cc9f8da008fd065d933e6d142dde854108d53a** and your existing local private editor addon. This overlay also works over earlier candidates using that base. Open `/fireside`.

No private addon source, archive, credentials or crash logs are included. Main and production releases are unchanged. The changed-files ZIP and patch contain the complete public integration against the base above.

## Camp layout

The user-confirmed **Furbolg tent, native M2 FileDataID 202016**, now loads as the single camp shelter. The Journal table and interactive badge/memento shelf sit beneath it. A campfire stands in front with four working chairs spaced around it and facing inward. The ground uses grass without the wooden path overlay; the existing sky remains.

A fresh scene-specific editor layout slot (`fireside-3d-camp8`) presents this arrangement without deleting earlier saved editor layouts. Existing scale, rotation and placement controls remain available for final decorating. The tent has decoration collision so its bounding box does not seal the entrance; furniture retains its existing collision and interactions. Journal reading, earned showcase, chair animations, movement, NPCs and Aether Live use their existing systems. Both multiplayer clients need candidate 8 because the world geometry digest changes.

The user's successful native render test confirms the tent asset. The new arrangement, exact entrance direction, furniture fit and visual scale still need client review.

## Input and grass fixes

- The gameplay input surface now releases clicks and mouse-wheel input while the menu or editor is open, allowing menu scrolling to reach the menu again.
- The existing editor receives a dedicated viewport input surface below its panel, with its own update driver. Camera controls: **WASD** fly/strafe, **Q/E** down/up, **Shift** faster, **right-drag** look, **wheel** dolly, **Reset camera** to return to the starting view. Guarded physical-input polling handles missed events. Forms, text focus, object dragging, combat and panel hover retain their input guards. Closing the editor restores the player camera.
- An unchanged camera is no longer reapplied every frame. Grass waits for stable native projection on startup/resize, retains its last valid geometry during temporary projection loss, and avoids idle UV rebuilding. Green backing covers asynchronous texture readiness, and strips use integer screen boundaries.

These changes stay inside the experimental 3D adapter. The shared native renderer, legacy 2.5D placement and authentication/storage implementations are unchanged.

## Validation and client check

Cloud checks pass for camp startup, one viewport, real realm lifecycle, lazy Journal, existing collision/animation/Live boundaries, 360-degree transform invariance, menu wheel delivery, editor input capture/release and camera movement, idle camera caching, and grass projection/texture readiness/resize recovery. Lua syntax, TOC references, protected base-source equality and package integrity/privacy checks also pass.

Cloud cannot run WoW. In the client, check the initial camp arrangement, click Journal/shelf, sit in a chair, scroll the menu, and move/look with the editor camera. Check grass on a cold open, during movement and after resizing. The regression checks demonstrate the intended behavior at recorded API boundaries; they do not certify the native visual result.

Manual catalog entries remain available, including the older WMO research candidates labeled unverified. None of those WMO models loads automatically, and Lua errors cannot contain a native renderer crash.

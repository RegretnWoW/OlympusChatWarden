# Fireside 3D — Hitbox editing, candidate 9

## Install

With WoW closed, extract **Fireside-3D-candidate9-overlay.zip** into `Interface/AddOns/`, replacing the public code/catalog. Keep your existing media and local private editor addon. This overlays candidate 8 (or the recorded public base **e4cc9f8da008fd065d933e6d142dde854108d53a** with its media).

The working forest camp, its assets, saved layout slot (`fireside-3d-camp8`), camera, grass, menu scrolling, movement, Journal, showcase, chairs and Live protocol are retained. Existing saved placements and single-box controls remain readable. No new models load.

## Edit hitboxes

1. Open the existing Scene Editor and select the tent or another loaded prop in its object list.
2. Click **Edit hitboxes** in the camera toolbar. The existing collision/click-area control commands also open this tool.
3. Choose **Walking** for green ground collision footprints, or **Click area** for blue interaction volumes. These are independent controls.
4. Drag **X-/X+/Y-/Y+** to adjust each side while holding the opposite side fixed. Click areas also have **Z-/Z+** for bottom/top. Drag the numbered **+** center to move a box along its horizontal plane. Rotate the free camera if a side is obscured or points straight toward the camera.
5. Use **Add box**, **Duplicate**, **Remove**, **On / Off**, **Auto-fit box** or **Exact values** as needed. Up to eight boxes are supported per object for each control. Click another box's number or use **Previous / Next** to select it. Selected edges are thicker; disabled boxes are gray.
6. Use the main editor's **Save** when finished. Existing **Undo/Redo** and **Export/Import** include the boxes. One drag is one undo step. **Escape** cancels an active drag; **Use automatic** removes that control's overrides and restores its original generated/default behavior.

For the tent: choose Walking and Add box. The first added box replaces its disabled automatic preview, so it does not accidentally enclose the whole tent. Resize/move one narrow box along each solid wall, adding more where needed. Leave the entrance and desired walking space empty. Navigation checks each box separately, preserving the gaps. Walking collision remains a ground footprint; changing a click area's height does not change walking clearance.

Boxes follow their object's rotation and scale. These are the existing editor's local authored layouts; the patch adds no layout synchronization or Live transport. Share a saved layout through the existing export/import workflow when matching local edits are needed. New exports use layout version 6 so an older editor cannot silently discard multiple boxes; earlier supported layouts still load. Keep candidate 9 when using these new saved layouts.

## Validation

Cloud checks cover three independent tent walls with a clear entrance through 360 degrees and multiple scales; real path validation; disabled/empty and legacy shapes; separate clickable volumes and their gaps; bounded data validation; all six anchored faces and native perspective inversion; actual tool controls/handles, dragging/cancel, camera isolation, one-step undo/redo and versioned export/reload. Existing camp lifecycle, menu/editor input, grass loading and Live codec/coalescing checks also pass. Lua/TOC syntax/references, protected base-source equality and public archive/privacy checks pass.

WoW cannot run in Cloud. The user confirmed candidate 8's camp and controls; candidate 9's new handle placement and native drag feel need a client check.

No private addon implementation, private archive, credentials or crash logs are included. Main and production releases are unchanged. The changed-files ZIP and patch contain the complete public experimental integration against the recorded base. Older WMO catalog entries remain manual and unverified; this patch does not load them.

# 1.1.3 release build notes

Source baseline: the retained 1.1.3-preview2 ZIP. Release notes cover the full change since 1.1.2. The final pass changes presentation only; the existing collectors, stores, schemas, consent, Relay transport, signed packs and backup tool remain byte-identical to preview 2.

## Final defects addressed

- `Art.Edit` returns a text box inside a separate backing panel. Hiding the text box left its panel and placeholder visible over the talent tree. The inline styled field is removed. A plain hidden value holder supports the existing separate copy dialog without creating any visible panel or placeholder.
- Zoom previously multiplied positions while leaving icon/text dimensions fixed. The tree now uses one scaled content frame inside an unscaled scroll canvas with explicit matching extents. Icons, ranks, headings and prerequisite lines inherit the same native scale.
- Zoom uses exact 25-point steps from 75% through 200%. Reset always applies 100% and zero scroll offsets. Zoom keeps the viewport center where bounds permit. Refreshes reuse the same view identity rather than resetting zoom on every render; a different character/player/build resets cleanly.
- The permanent instruction paragraph is removed, controls have hover tooltips, and the tree receives more vertical space. Historical identity, observation date, uncertainty and the original export remain accessible.

## Verification

See Validation JSON for source hash and exact suite results. The final zoom suite checks 26 conditions, including shared scale inheritance, deterministic Reset from every zoom level, refresh/identity behavior, copy preservation and 100 repeated zoom cycles without frame accumulation. Saved talent evidence remains byte-equivalent.

The release retains inspection, equipment, cold report-view, module isolation, startup/recovery, archive, Relay, scale and backup regressions. All Lua modules are compiled using Lua 5.1. The Windows backup utility is checked in both Windows PowerShell and PowerShell 7 with synthetic files only.

Production-widget layout previews at 100% and 125% show the removed overlay and the complete content scaling. Their spell textures and data are synthetic and they are not native screenshots. The supplied user screenshot confirms the earlier overlap and spacing-only zoom; it does not verify this fix in the live client.

## Release limits

WoW was not operated during this build. Native zoom/scroll behavior and the reported tooltip/shortcut fixes still need client acceptance. No publication, live installation or personal SavedVariables change was performed. Main history schema remains 6, consent version remains 5, and all three SavedVariables identities remain unchanged. There is no deletion, truncation, expiration or collection reduction.

The bundle includes the unchanged 1.0.3 Windows backup tool. Older readers that predate the optional native talent metadata cannot validate those newer snapshots; keep a complete backup and isolated saved data for rollback testing.

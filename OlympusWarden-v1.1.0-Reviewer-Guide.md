# Olympus Warden 1.1.0 — installation and final checks

Close WoW and make a complete SavedVariables backup using the included separate
Windows backup-tool ZIP before switching. 1.1.0 and stable 1.0.3 share addon folder
OlympusChatWarden and SavedVariables OlympusChatWardenDB. Use isolated WTF/client
environments to compare; retain the backup and exact RC5 rollback ZIP.

## First test: the reported window-size bug

1. Open Settings > Window size. Move the slider: only the proposed percentage
   should change. Press Apply; the panel should resize once.
2. Enter a percentage from 50 to 150 and press Enter. Reopen the editor; the saved
   percentage should match. Leave another adjustment unapplied and navigate away;
   reopening should discard the draft and show the saved percentage.
3. Open Updates & Help > Launch Tour (or the Welcome action), then IntelWarden,
   ChronicleWarden and Settings repeatedly. The window should keep the same size.
4. Use Fit to screen, repeat navigation and /reload. Automatic size should stay
   stable for the same screen/UI scale and respect the panel bounds.
5. Try WoW UI scales .64, .8 and 1 and the target resolutions 1366x768, 1920x1080,
   2560x1600 and 3840x2160 where available. A screen cap can reduce displayed size
   without replacing a saved custom percentage. Report saved/displayed values,
   resolution and WoW UI scale if they disagree unexpectedly.

## Suite tour

Warden: system state, suite search and recent milestones.
ChatWarden: Messages, Capture, Rules, Packs and Reports.
SignalWarden: personal mentions, Wanted encounter alerts and permitted OlympusMute
signals; Wanted names in chat remain quiet icon/hover information.
ShieldWarden: contact protection, shielded/allowed players and review.
IntelWarden: remembered players, relationships, private notes, gear and talents.
ChronicleWarden: milestones, activities, duels and measured time.
Data & Backups: recorded evidence, optional consent, full backups and diagnostics.

Recording starts off for fresh users; existing consent is retained. Duel recording
requires its separate permission. Pausing keeps history. No automatic expiry or
sharing. Private notes stay local. Do not clear real history to test a button;
exercise destructive confirmation only in an isolated test environment.

## Focused acceptance

- Review a long Chat/Signal/Shield record; scroll to its end. Protected originals
  must remain concealed until deliberately revealed. Check selected/unread/hover
  and disabled actions, exact record selection and compact mark-read links.
- Save a private note, then leave another unsaved; open Original record and return.
  Verify exact player, note draft and scroll are retained.
- Normally Inspect a player. Confirm the same GUID's gear persists after reload.
  Check historical talent names/ranks, and honest unavailable fields.
- Appearance: correct live model only, rotation/zoom/reset; target switching and
  unavailable/offline models must never substitute another player.
- Browse Chronicle activities, date/location, sources and pagination. Check Show
  all slots in duel comparisons without changing the selected phase/evidence.
- With duel consent, test incoming/outgoing duels and repeated opponent sessions.
  Verify results against actual play and unchanged snapshot reuse.
- Verify one dungeon/boss record, one battleground/objective report, native
  Statistics values and fresh final scores; preserve uncertainty where unavailable.
- Reload/logout with retained history and recording active; confirm totals,
  profiles, notes, gear, talents and consent return without errors.
- Measure /warden perf with suite closed/open under matched gameplay conditions.

Synthetic previews and tests establish offline behavior only. Record native results
separately. Keep bug reports focused on actual observations and first Lua errors.

## Final artwork and navigation checks

Chronicle and Intel appear directly below Warden. Module IDs and existing links
are unchanged. Verify larger crests/buttons, readable guild/rank, and clear Zeus.
Toggle each recent-activity control repeatedly: logo identity must stay fixed,
ON/OFF and dimming must match. Hover and leave paused controls; they must stay off.
Switch from a paused feature to Chronicle; its crest must return to full color.
Scroll historical talents to the last row and verify complete names/ranks.
Switch retained character and selected player; no other dossier may remain visible.
Open original evidence and return with an unsaved note; check selection and draft.
Use /warden perf for matched long-session measurements and report first Lua errors.
